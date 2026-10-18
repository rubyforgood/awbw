module PersonServices
  # Turns FileMaker Rolodex archive rows (FmRolodex) into people. Each row lands in
  # one outcome bucket of #results:
  #   * created          — new Person: the fields FmRolodex::PORTAL_FIELDS maps to a
  #                        person (including the sector/age tags its service areas,
  #                        settings, life experiences and age group translate to, and
  #                        the archive's own entry date), plus the row's addresses and
  #                        phones
  #   * linked           — every person PersonMatcher finds for the row's name + email
  #                        (which reaches their secondary and login addresses too), or
  #                        every same-name person with no email when the row has none,
  #                        adds the row's ID to their filemaker_code list and is filled
  #                        from it: blank fields take the archive's value, missing
  #                        addresses, phones and tags are added, and a field the archive
  #                        disagrees on keeps the person's value — noted in #differences
  #                        and as a comment on the person
  #   * already_imported — a person already carries the row's ID
  #   * skipped          — agency, soft-deleted, or nameless rows
  #   * failed           — the Person didn't validate
  #
  # A row whose name + email matches nobody is created, even when someone already shares
  # the name or the email: folding the occasional duplicate with the person deduper beats
  # hand-resolving every collision in a 39,000-row archive.
  class ImportFromRolodex
    OUTCOMES = %i[created linked already_imported skipped failed].freeze
    FALSE_FLAGS = %w[0 n no false].freeze
    DATE_FORMATS = %w[%m/%d/%Y %Y-%m-%d %m-%d-%Y %Y/%m/%d].freeze
    # A two-digit year below this is read as 20xx, at or above it as 19xx.
    TWO_DIGIT_YEAR_PIVOT = 10
    CONTACT_TYPES = { "home" => "personal", "personal" => "personal", "cell" => "personal",
                      "mobile" => "personal", "work" => "work", "mailing" => "mailing" }.freeze
    EMAIL_PATTERN = /[^\s,;<>"']+@[^\s,;<>"']+\.[^\s,;<>"']+/
    UNKNOWN_LOCALITY = "Unknown"
    STRING_LIMIT = 255

    # Whether a translated tag lands as primary or additional follows the field (ADR-0007).
    PRIMARY_TAG_FIELDS = %w[PrimaryServiceArea PrimaryAgeGroup].freeze
    ADDITIONAL_TAG_FIELDS = %w[OtherServiceArea Settings LifeExperiences].freeze
    PRIMARY_TAG_LABELS = { tag_sectors: "Primary sector", tag_age_groups: "Primary age group" }.freeze

    attr_reader :results, :differences

    def initialize(scope: FmRolodex.all)
      @scope = scope
      @results = OUTCOMES.index_with { [] }
      @differences = []
      @imported_codes = Person.where.not(filemaker_code: [ nil, "" ]).pluck(:filemaker_code)
                              .flat_map { |value| Person.split_filemaker_codes(value) }.to_set
      @translation = TagTranslation.new
    end

    def call
      @scope.find_each { |rolodex| import(rolodex) }
      self
    end

    def unmatched_tags
      @translation.unmatched
    end

    private

    def import(rolodex)
      data = rolodex.data
      first_name = Person.normalize_name(data["FirstName"]).to_s
      last_name = Person.normalize_name(data["LastName"]).to_s
      label = "#{rolodex.fm_id} #{first_name} #{last_name}".squish

      return record(:already_imported, label) if @imported_codes.include?(rolodex.fm_id)
      return record(:skipped, "#{label}: agency") if flag?(data["isAgency__c"])
      return record(:skipped, "#{label}: marked deleted") if flag?(data["Delete"])
      return record(:skipped, "#{label}: missing first or last name") if first_name.blank? || last_name.blank?

      email, email_2 = data["EMail"].to_s.scan(EMAIL_PATTERN)

      if email
        match = PersonMatcher.new(email:, last_name:, first_names: [ first_name ]).matches.to_a
        return link(match, rolodex, label) if match.any?
      else
        no_email = Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", first_name.downcase, last_name.downcase)
                         .where(email: [ nil, "" ]).to_a
        return link(no_email, rolodex, label) if no_email.any?
      end

      create(rolodex, label, first_name:, last_name:, email:, email_2:)
    end

    # Several matches are one person entered more than once, so each carries the code
    # and the deduper unions them when they're merged.
    def link(people, rolodex, label)
      people.each do |person|
        person.filemaker_code = Person.join_filemaker_codes(person.filemaker_code, rolodex.fm_id)
        kept = fill(person, rolodex)
        return record(:failed, "#{label}: ##{person.id} #{person.errors.full_messages.to_sentence}") unless person.save

        kept.concat(tag_service_areas(person, rolodex.data))
        note_differences(person, rolodex, label, kept) if kept.any?
      end

      @imported_codes << rolodex.fm_id
      record(:linked, "#{label} → #{ids(people)}")
    end

    def create(rolodex, label, **names)
      data = rolodex.data
      person = Person.new(**names, filemaker_code: rolodex.fm_id, **profile_attributes(data), **archive_timestamps(data))
      build_addresses(person, rolodex)
      build_phones(person, rolodex)

      return record(:failed, "#{label}: #{person.errors.full_messages.to_sentence}") unless person.save

      tag_service_areas(person, data)
      # Tagging touches the person, so the archive's dates are written once more here —
      # update_columns, so the touch doesn't win.
      timestamps = archive_timestamps(data)
      person.update_columns(timestamps) if timestamps.any?
      @imported_codes << rolodex.fm_id
      record(:created, "#{label} → ##{person.id}")
    end

    def profile_attributes(data)
      {
        pronouns: clip(data["Pronouns"]),
        best_time_to_call: clip(data["BestTimeToCall"]),
        racial_ethnic_identity: clip(data["Ethnicity"]),
        date_of_birth: parse_date(data["DateOfBirth"]),
        email_type: email_type(data["EmailType"]),
        member_since: member_since(data),
        notes: data["Comments"].presence
      }
    end

    # Staff edited both systems, so neither side is newer by rule: a blank takes the
    # archive's value, and a disagreement keeps the person's and is returned as
    # [ label, portal value, archive value ] to note.
    def fill(person, rolodex)
      kept = profile_attributes(rolodex.data).filter_map do |attribute, value|
        next if value.blank?
        next person[attribute] = value if person[attribute].blank?
        next if same?(person[attribute], value)

        [ Person.human_attribute_name(attribute), person[attribute], value ]
      end
      fill_email_2(person, rolodex.data)
      build_addresses(person, rolodex)
      build_phones(person, rolodex)
      kept
    end

    def fill_email_2(person, data)
      return if person.email_2.present?

      held = [ person.email, person.user&.email ].compact_blank.map(&:downcase)
      person.email_2 = data["EMail"].to_s.scan(EMAIL_PATTERN).find { |email| held.exclude?(email.downcase) }
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

    # The archive's own entry and modification dates, so an imported person dates from
    # when FileMaker first knew them rather than from the import run.
    def archive_timestamps(data)
      entered = parse_date(data["DateEntered"])
      { created_at: entered, updated_at: parse_date(data["DateTimeModified"]) || entered }.compact
    end

    def email_type(value)
      CONTACT_TYPES[value.to_s.strip.downcase].presence_in(Person::CONTACT_TYPES)
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
      primary = translate(data, PRIMARY_TAG_FIELDS)
      additional = translate(data, ADDITIONAL_TAG_FIELDS)
      sector_primary_ids, sector_extra_ids = split_primary(primary.flat_map(&:sector_ids).uniq)
      age_primary_ids, age_extra_ids = split_primary(primary.flat_map(&:age_group_ids).uniq)

      [
        apply_tags(person, :tag_sectors, Sector, person.sectorable_items.where(is_primary: true).pluck(:sector_id),
                   primary_ids: sector_primary_ids, additional_ids: sector_extra_ids + additional.flat_map(&:sector_ids)),
        apply_tags(person, :tag_age_groups, Category, person.primary_age_category_ids,
                   primary_ids: age_primary_ids, additional_ids: age_extra_ids + additional.flat_map(&:age_group_ids))
      ].compact
    end

    def apply_tags(person, tag_with, model, held_ids, primary_ids:, additional_ids:)
      if held_ids.any?
        difference = [ PRIMARY_TAG_LABELS[tag_with], names(model, held_ids), names(model, primary_ids) ] unless (primary_ids - held_ids).empty?
        primary_ids, additional_ids = [], primary_ids + additional_ids
      end
      person.public_send(tag_with, primary_ids:, additional_ids:) if (primary_ids + additional_ids).any?
      difference
    end

    def translate(data, fields)
      fields.map { |field| @translation.resolve(data[field]) }
    end

    # A primary answer naming several of a kind — "Families" is every age range — has no
    # single one to pick, so they all land as additional.
    def split_primary(ids)
      ids.one? ? [ ids, [] ] : [ [], ids ]
    end

    def names(model, ids)
      model.where(id: ids).pluck(:name).to_sentence
    end

    # Every address the row answers to, not just the one it names as primary —
    # FmRolodex#addresses lists them with the primary and worksite ones first, so the
    # first that can be built is the person's primary and the rest ride along. One the
    # person already has is left out, and a primary they already hold stays primary.
    def build_addresses(person, rolodex)
      held = person.addresses.map { |address| address_key(address.street_address, address.city) }
      attributes = rolodex.addresses.filter_map { |address| address_attributes(address.data) }
                          .reject { |attrs| held.include?(address_key(attrs[:street_address], attrs[:city])) }
      build_primary_first(person.addresses, attributes)
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
      city = fields["AddrsCity"].to_s.strip
      state = fields["AddrsState"].to_s.strip
      return if street.blank? || city.blank? || state.blank?

      {
        street_address: clip(street),
        city:,
        state:,
        zip_code: fields["AddrsPostalCode"].to_s.strip,
        country: clip(fields["AddrsCountry"]),
        address_type: contact_type(fields["AddrsType"], allowed: Address::CONTACT_TYPES),
        locality: UNKNOWN_LOCALITY
      }
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
    # bounded by, and an over-long incidental field would otherwise cost the person.
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
