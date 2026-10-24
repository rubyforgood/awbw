module PersonServices
  # Turns FileMaker Rolodex archive rows (FmRolodex) into people. Each row lands in
  # one outcome bucket of #results:
  #   * created          — new Person: the fields FmRolodex::PORTAL_FIELDS maps to a
  #                        person (including the sector/age tags its service areas,
  #                        settings, life experiences and age group translate to, and
  #                        the archive's own entry date), plus the row's addresses and
  #                        phones
  #   * linked           — every person PersonMatcher finds for the row's name + one of
  #                        its emails (reaching the person's secondary and login
  #                        addresses too), or every same-name person with no email when
  #                        the row holds none, adds the row's ID to their filemaker_code
  #                        list and is filled from it: blank fields take the archive's
  #                        value, missing addresses, phones and tags are added, and a
  #                        field the archive disagrees on keeps the person's value —
  #                        noted in #differences and as a comment on the person
  #   * already_imported — a person already carries the row's ID
  #   * skipped          — agency, soft-deleted, or nameless rows
  #   * failed           — the Person didn't validate
  #
  # An email field holding no address the person's email validation accepts ("ada@@x.org",
  # "ada at x dot org") or an address it rejects is left off — the row imports without it.
  # When that leaves the person with no email on file, the field's whole value is left as a
  # comment on the person and listed in #invalid_emails, so it can be fixed by hand. A row
  # with no usable address left is always a new person, given the next free placeholder
  # email (1@…, 2@…) when someone already carries the name.
  #
  # A row whose name + email matches nobody is created, even when someone already shares
  # the name or the email: folding the occasional duplicate with the person deduper beats
  # hand-resolving every collision in a 39,000-row archive.
  #
  # `relink: true` reads a row whose ID a person already carries anyway, which is how a
  # match that failed the first time is picked up once the person is valid: the matches
  # already holding the ID are left as they are and only the rest are filled. Meant for a
  # named handful of rows (the task's FM_IDS), since a row whose created person has since
  # changed their email no longer matches and would be created again.
  class ImportFromRolodex
    OUTCOMES = %i[created linked already_imported skipped failed].freeze
    FALSE_FLAGS = %w[0 n no false].freeze
    DATE_FORMATS = %w[%m/%d/%Y %Y-%m-%d %m-%d-%Y %Y/%m/%d].freeze
    # A two-digit year below this is read as 20xx, at or above it as 19xx.
    TWO_DIGIT_YEAR_PIVOT = 10
    CONTACT_TYPES = { "home" => "personal", "personal" => "personal", "cell" => "personal",
                      "mobile" => "personal", "work" => "work", "business" => "work",
                      "professional" => "work", "mailing" => "mailing" }.freeze
    # Answers to "which kind of email is this?" that aren't a kind at all.
    PRECEDENCE_TYPES = %w[preferred primary main].freeze
    EMAIL_PATTERN = /[^\s,;<>"']+@[^\s,;<>"']+\.[^\s,;<>"']+/
    # EmailPrimary holds a flag ("1" or "2"), never an address, so only EMail is read for one.
    EMAIL_FIELDS = %w[EMail].freeze
    STRING_LIMIT = 255
    BATCH_SIZE = 1_000

    # Whether a translated tag lands as primary or additional follows the field (ADR-0007).
    # Both primary fields can name either kind of tag, so each kind reads the same two
    # fields with the one that owns it first: the service area names the sector, the age
    # group field the age range.
    PRIMARY_SECTOR_FIELDS = %w[PrimaryServiceArea PrimaryAgeGroup].freeze
    PRIMARY_AGE_FIELDS = PRIMARY_SECTOR_FIELDS.reverse.freeze
    ADDITIONAL_TAG_FIELDS = %w[OtherServiceArea Settings LifeExperiences].freeze
    PRIMARY_TAG_LABELS = { tag_sectors: "Primary sector", tag_age_groups: "Primary age group" }.freeze

    attr_reader :results, :differences, :invalid_emails

    def initialize(scope: FmRolodex.all, relink: false, progress: nil, run: nil)
      @scope = scope
      @relink = relink
      @progress = progress
      @run = run
      @results = OUTCOMES.index_with { [] }
      @differences = []
      @invalid_emails = []
      @imported_codes = Person.where.not(filemaker_code: [ nil, "" ]).pluck(:filemaker_code)
                              .flat_map { |value| Person.split_filemaker_codes(value) }.to_set
      @translation = TagTranslation.new
      @staff = StaffTranslation.new
      @import_user_id = Setting.import_user&.id
    end

    def call
      @tracker = Ahoy::Tracker.new
      @address_index = FmRolodex.contact_index(FmAddress)
      @phone_index = FmRolodex.contact_index(FmPhoneNumber)
      read = 0
      @scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        import_batch(batch)
        @progress&.call(read += batch.size)
      end
      self
    end

    def unmatched_tags
      @translation.unmatched
    end

    def unmatched_staff
      @staff.unmatched
    end

    private

    # Each batch commits on its own (a savepoint inside a dry run's rollback), so a run that
    # stops partway keeps what it finished; the rerun skips those rows as already imported.
    # Its activity events, tagged with the run, commit with it — UndoRolodexImport reads them.
    def import_batch(batch)
      ActiveRecord::Base.transaction(requires_new: true) do
        Analytics::LifecycleBuffer.tagging(@run ? { import_run: @run } : {}) do
          batch.each { |rolodex| import(rolodex.preload_contacts(addresses: @address_index, phone_numbers: @phone_index)) }
        end
        Analytics::LifecycleBuffer.flush_to(@tracker)
      end
    end

    def import(rolodex)
      data = rolodex.data
      first_name = Person.normalize_name(data["FirstName"]).to_s
      last_name = Person.normalize_name(data["LastName"]).to_s
      label = "#{rolodex.fm_id} #{first_name} #{last_name}".squish

      return record(:already_imported, label) if !@relink && @imported_codes.include?(rolodex.fm_id)
      return record(:skipped, "#{label}: agency") if flag?(data["isAgency__c"])
      return record(:skipped, "#{label}: marked deleted") if flag?(data["Delete"])
      return record(:skipped, "#{label}: missing first or last name") if first_name.blank? || last_name.blank?

      row_emails = emails(data)
      email, email_2 = row_emails
      match = match_people(rolodex, row_emails, first_name, last_name)
      return link(match, rolodex, label) if match.any?

      create(rolodex, label, first_name:, last_name:, email:, email_2:)
    end

    # Everyone the row's name and any of the addresses it holds reaches — the person sees
    # each of them as their email, so a row whose second field carries the one the portal
    # knows still finds them. A row with no address at all can only go by the name, and
    # then only to someone the portal has no email for either. One whose only addresses are
    # unusable says nothing about who it is, so it reaches just the person it already made.
    def match_people(rolodex, row_emails, first_name, last_name)
      return Person.with_filemaker_code(rolodex.fm_id).to_a if row_emails.empty? && invalid_email_values(rolodex.data).any?
      return same_name_without_email(first_name, last_name) if row_emails.empty?

      row_emails.lazy.map { |email| PersonMatcher.new(email:, last_name:, first_names: [ first_name ]).matches.to_a }
                .find(&:any?) || []
    end

    def same_name_without_email(first_name, last_name)
      same_name(first_name, last_name).where(email: [ nil, "" ]).to_a
    end

    def same_name(first_name, last_name)
      Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", first_name.downcase, last_name.downcase)
    end

    # Several matches are one person entered more than once, so each carries the code
    # and the deduper unions them when they're merged.
    def link(people, rolodex, label)
      linked = people.select { |person| link_person(person, rolodex, label) }
      return if linked.empty?

      @imported_codes << rolodex.fm_id
      record(:linked, "#{label} → #{ids(linked)}")
    end

    # One match of the row, reported and left out when it doesn't validate so the row's
    # other matches still take the code. A re-run reaches the matches that already carry
    # the ID as well, and filling them again would note every difference a second time.
    def link_person(person, rolodex, label)
      return true if person.filemaker_codes.include?(rolodex.fm_id)

      person.filemaker_code = Person.join_filemaker_codes(person.filemaker_code, rolodex.fm_id)
      kept = fill(person, rolodex)
      return failed(person, label) unless person.save

      kept.concat(tag_service_areas(person, rolodex.data))
      note_differences(person, rolodex, label, kept) if kept.any?
      note_invalid_emails(person, rolodex, label)
      true
    end

    def failed(person, label)
      record(:failed, "#{label}: ##{person.id} #{person.errors.full_messages.to_sentence}")
      false
    end

    def create(rolodex, label, **names)
      data = rolodex.data
      person = Person.new(**names, filemaker_code: rolodex.fm_id, **profile_attributes(data),
                          **archive_timestamps(data), **archive_stamps(data))
      person.email = person.next_free_placeholder_email if needs_placeholder_email?(person, data)
      build_addresses(person, rolodex)
      build_phones(person, rolodex)

      # Its tags would touch the person when the batch commits, overwriting the archive's
      # dates it was created with.
      Person.no_touching do
        return record(:failed, "#{label}: #{person.errors.full_messages.to_sentence}") unless person.save

        tag_service_areas(person, data)
        note_invalid_emails(person, rolodex, label)
      end
      @imported_codes << rolodex.fm_id
      record(:created, "#{label} → ##{person.id}")
    end

    def needs_placeholder_email?(person, data)
      person.email.blank? && invalid_email_values(data).any? && same_name(person.first_name, person.last_name).exists?
    end

    def profile_attributes(data)
      {
        pronouns: clip(data["Pronouns"]),
        best_time_to_call: clip(data["BestTimeToCall"]),
        racial_ethnic_identity: clip(data["Ethnicity"]),
        date_of_birth: parse_date(data["DateOfBirth"]),
        email_type: email_type(data["EmailType"]),
        member_since: member_since(data)
      }
    end

    # Staff edited both systems, so neither side is newer by rule: a blank takes the
    # archive's value, and a disagreement keeps the person's and is returned as
    # [ label, portal value, archive value ] to note.
    def fill(person, rolodex)
      kept = profile_attributes(rolodex.data).filter_map do |attribute, value|
        next if value.blank?

        if person[attribute].blank?
          person[attribute] = value
          next
        end
        next if same?(person[attribute], value) || value == Person::UNKNOWN_CONTACT_TYPE

        [ Person.human_attribute_name(attribute), person[attribute], value ]
      end
      fill_email_2(person, rolodex.data)
      archive_stamps(rolodex.data).each { |attribute, user_id| person[attribute] ||= user_id }
      build_addresses(person, rolodex)
      build_phones(person, rolodex)
      kept
    end

    def fill_email_2(person, data)
      return if person.email_2.present?

      held = [ person.email, person.user&.email ].compact_blank.map(&:downcase)
      person.email_2 = emails(data).find { |email| held.exclude?(email.downcase) }
    end

    # The archive words an email field freely ("Attn: someone", a note, two addresses at
    # once), so each is read for the addresses in it; the same one twice counts once.
    def emails(data)
      EMAIL_FIELDS.flat_map { |field| data[field].to_s.scan(EMAIL_PATTERN) }.select { |email| valid_email?(email) }.uniq(&:downcase)
    end

    def invalid_email_values(data)
      EMAIL_FIELDS.filter_map { |field| data[field].to_s.strip.presence }
                  .reject { |value| usable_email_value?(value) }.uniq
    end

    def usable_email_value?(value)
      addresses = value.scan(EMAIL_PATTERN)
      addresses.any? && addresses.all? { |email| valid_email?(email) }
    end

    def valid_email?(email)
      email.length <= STRING_LIMIT && email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def same?(portal, archive)
      portal.to_s.squish.casecmp?(archive.to_s.squish)
    end

    def note_differences(person, rolodex, label, kept)
      lines = kept.map { |field, portal, archive| "#{field}: kept “#{portal}”, FileMaker has “#{archive}”" }
      Comment.create!(commentable: person,
                      body: "FileMaker Rolodex #{rolodex.fm_id} differs from this profile:\n#{lines.join("\n")}")
      @differences << "#{label} → ##{person.id}: #{lines.join('; ')}"
    end

    def note_invalid_emails(person, rolodex, label)
      return if person.email_on_file

      values = invalid_email_values(rolodex.data)
      return if values.empty?

      quoted = values.map { |value| "“#{value}”" }
      Comment.create!(commentable: person,
                      body: "FileMaker Rolodex #{rolodex.fm_id} has an email this profile couldn't take:\n#{quoted.join("\n")}")
      @invalid_emails << "#{label} → ##{person.id}: #{quoted.join('; ')}"
    end

    # The staff FileMaker recorded as entering and last changing the row (StaffAlias), or
    # the settings' import user when the archive names no one we can resolve, so every
    # person carries both stamps. A linked person keeps any stamps they already have.
    def archive_stamps(data)
      { created_by_id: @staff.user_id_for(data["EnteredBy"]) || @import_user_id,
        updated_by_id: @staff.user_id_for(data["ModifiedBy"]) || @import_user_id }.compact
    end

    # The archive's own entry and modification dates, so an imported person dates from
    # when FileMaker first knew them rather than from the import run.
    def archive_timestamps(data)
      entered = parse_date(data["DateEntered"])
      { created_at: entered, updated_at: parse_date(data["DateTimeModified"]) || entered }.compact
    end

    # Which kind of email the archive says this is. A word that says precedence rather than
    # kind leaves the type unrecorded: "Preferred" says this is the address to use — which
    # the email's own slot already says — and nothing about work or personal. A kind we have
    # no word for ("Attn: …", a name) does say someone recorded one, so it reads as unknown;
    # a blank stays untyped.
    def email_type(value)
      key = value.to_s.strip.downcase
      return if key.blank? || PRECEDENCE_TYPES.include?(key)

      CONTACT_TYPES[key].presence_in(Person::CONTACT_TYPES) || Person::UNKNOWN_CONTACT_TYPE
    end

    # FileMaker keeps the facilitator's start as a separate month and year; the portal
    # keeps one date, and a year with no month reads as January.
    def member_since(data)
      year = data["FacilitatorSinceYear"].to_s[/\A\d{4}\z/]
      return unless year

      Date.new(year.to_i, month_number(data["FacilitatorSinceMonth"]) || 1, 1)
    end

    def month_number(value)
      value = value.to_s.strip
      return value.to_i if value.match?(/\A(0?[1-9]|1[0-2])\z/)

      [ Date::MONTHNAMES, Date::ABBR_MONTHNAMES ].filter_map { |names| names.index { |name| name&.casecmp?(value) } }.first
    end

    # The archive's who-they-serve fields tag the person additively, since the import is
    # never the whole picture. A primary the person already holds stays; the archive's
    # then lands as additional and is returned as a difference to note.
    def tag_service_areas(person, data)
      primary_answers = translate(data, PRIMARY_SECTOR_FIELDS)
      additional = translate(data, ADDITIONAL_TAG_FIELDS).values
      sector_primary_ids, sector_extra_ids = split_primary(primary_answers.values_at(*PRIMARY_SECTOR_FIELDS).map(&:sector_ids))
      age_primary_ids, age_extra_ids = split_primary(primary_answers.values_at(*PRIMARY_AGE_FIELDS).map(&:age_group_ids))

      [
        apply_tags(person, :tag_sectors, Sector, person.sectorable_items.where(is_primary: true).pluck(:sector_id),
                   primary_ids: sector_primary_ids, additional_ids: sector_extra_ids + additional.flat_map(&:sector_ids)),
        apply_tags(person, :tag_age_groups, Category, person.primary_age_groups.map(&:id),
                   primary_ids: age_primary_ids, additional_ids: age_extra_ids + additional.flat_map(&:age_group_ids))
      ].compact
    end

    # A tag the person already holds as primary is left out of the additional set, since
    # tagging it additional is what would demote it.
    def apply_tags(person, tag_with, model, held_ids, primary_ids:, additional_ids:)
      if held_ids.any?
        difference = [ PRIMARY_TAG_LABELS[tag_with], names(model, held_ids), names(model, primary_ids) ] unless (primary_ids - held_ids).empty?
        primary_ids, additional_ids = [], (primary_ids + additional_ids) - held_ids
      end
      person.public_send(tag_with, primary_ids:, additional_ids:) if (primary_ids + additional_ids).any?
      difference
    end

    def translate(data, fields)
      fields.index_with { |field| @translation.resolve(data[field]) }
    end

    # A person holds one primary sector and one primary age range, so the first field to
    # name a single tag of the kind gives it. An answer naming several — "Families" is
    # every age range — has no single one to pick, so the next field gets its turn and
    # the rest land as additional.
    def split_primary(id_sets)
      primary = id_sets.find(&:one?) || []
      [ primary, id_sets.flatten.uniq - primary ]
    end

    def names(model, ids)
      model.where(id: ids).pluck(:name).to_sentence
    end

    # Every address the row answers to, not just the one it names as primary —
    # FmRolodex#addresses lists the primary first, so the first that can be built is the
    # person's primary and the rest ride along. A work address, one the person already
    # has, and a primary they already hold are all left as they are.
    def build_addresses(person, rolodex)
      held = person.addresses.map { |address| address_key(address.street_address, address.city) }
      attributes = rolodex.addresses.reject { |address| work_address?(rolodex, address) }
                          .filter_map { |address| address_attributes(address.data) }
                          .reject { |attrs| held.include?(address_key(attrs[:street_address], attrs[:city])) }
      build_primary_first(person.addresses, attributes)
    end

    # A work address belongs to the person's organization, so the affiliations import brings it in.
    def work_address?(rolodex, address)
      address.fm_id == rolodex.data["WorksiteAddrsID"] ||
        contact_type(address.data["AddrsType"], allowed: Address::CONTACT_TYPES) == "work"
    end

    def build_phones(person, rolodex)
      held = person.contact_methods.map { |phone| phone_key(phone.value) }
      attributes = rolodex.phone_numbers.filter_map { |phone| phone_attributes(phone.data) }
                          .reject { |attrs| held.include?(phone_key(attrs[:value])) }
      build_primary_first(person.contact_methods, attributes)
    end

    def build_primary_first(association, attributes)
      has_primary = association.any?(&:primary?)
      attributes.each_with_index { |attrs, index| association.build(attrs.merge(primary: index.zero? && !has_primary)) }
    end

    def address_key(street, city)
      [ AddressNormalizer.street(street), AddressNormalizer.city(city) ]
    end

    def phone_key(value)
      value.to_s.gsub(/\D/, "")
    end

    def address_attributes(fields)
      street = [ street_line(fields), fields["AddrsLine2"] ].filter_map { |line| line.to_s.strip.presence }.join(", ")
      city = clip(fields["AddrsCity"].to_s.strip)
      state = clip(fields["AddrsState"].to_s.strip)
      return if street.blank? || city.blank? || state.blank?

      country = clip(fields["AddrsCountry"])
      county = county(fields)
      {
        street_address: clip(street),
        city:,
        state:,
        zip_code: zip_code(fields),
        country:,
        county:,
        address_type: contact_type(fields["AddrsType"], allowed: Address::CONTACT_TYPES),
        # FileMaker records a locality only on a project, so a person's own address has
        # none to carry over and the parts have to say.
        locality: AddressLocality.for(city:, state:, country:, county:)
      }
    end

    # The address's own postal code, or the one it points at in the archive's ZIP table
    # when it carries none itself — the field it mirrors, and where the county is read.
    def zip_code(fields)
      [ fields["AddrsPostalCode"], fields["PostalCodeLookup"] ]
        .filter_map { |value| value.to_s.strip.presence }.first.to_s.truncate(STRING_LIMIT)
    end

    def county(fields)
      zip_counties[zip_lookup(fields)[/\A\d{5}/]]
    end

    def zip_lookup(fields)
      (fields["PostalCodeLookup"].presence || fields["AddrsPostalCode"]).to_s.strip
    end

    # One query for the archive's ~80,000 zip codes beats one per address across a full import.
    def zip_counties
      @zip_counties ||= FmPostalCode.pluck(:fm_id, Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.County'))"))
                                    .to_h { |zip, county| [ zip, clip(county) ] }
    end

    def phone_attributes(fields)
      number = clip(fields["PhoneNumber"])
      return if number.blank?

      { kind: "phone", value: number, contact_type: contact_type(fields["PhoneType"], allowed: ContactMethod::CONTACT_TYPES) }
    end

    # The archive's types map onto one set of ours, but each model declares the slice it
    # accepts — an address can be the mailing one, a phone number can't. A type we can't
    # place is left blank, which both models then record as unknown.
    def contact_type(value, allowed:)
      CONTACT_TYPES[value.to_s.strip.downcase].presence_in(allowed)
    end

    # The house number has its own field, sometimes already repeated at the front of
    # the first line.
    def street_line(fields)
      number = fields["StreetNo"].to_s.strip
      line = fields["AddrsLine1"].to_s.strip
      return line if number.blank? || line[/\A\S+/] == number

      "#{number} #{line}".strip
    end

    # Every string copied here lands in a varchar(255) the archive's free text isn't
    # bounded by, and an over-long incidental field would otherwise cost the person —
    # or, for a column with no length validation behind it, raise mid-import.
    def clip(value)
      value.presence && value.to_s.truncate(STRING_LIMIT)
    end

    def parse_date(value)
      value = value.to_s.strip
      return if value.blank?

      DATE_FORMATS.each do |format|
        parsed = parse_with(value, format)
        return parsed if parsed
      end
      nil
    end

    # Parsing stops where the format ends, so "10-5-1983" read as %Y-%m-%d takes 19
    # as the day and drops the 83 — digits left over mean the format split the value
    # in the wrong place, so the next one gets its turn.
    def parse_with(value, format)
      parts = Date._strptime(value, format)
      return if parts.nil? || parts[:leftover].to_s.match?(/\A\d/)

      expand_century(Date.new(parts[:year], parts[:mon], parts[:mday]))
    rescue Date::Error, TypeError
      nil
    end

    # %Y reads a two-digit year as the year itself, so "10/5/83" is 83 AD. The archive
    # mixes two- and four-digit years, so a bare pair gets a century: 83 is 1983, 05 is 2005.
    def expand_century(date)
      return date if date.year >= 100

      date.change(year: date.year + (date.year < TWO_DIGIT_YEAR_PIVOT ? 2000 : 1900))
    end

    def flag?(value)
      value.to_s.strip.presence && !FALSE_FLAGS.include?(value.to_s.strip.downcase)
    end

    def ids(people)
      people.map { |person| "##{person.id}" }.join(", ")
    end

    def record(outcome, message)
      @results[outcome] << message
    end
  end
end
