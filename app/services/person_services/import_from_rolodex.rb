module PersonServices
  # Turns FileMaker Rolodex archive rows (FmRolodex) into people. Each row lands in
  # one outcome bucket of #results:
  #   * created          — new Person: the fields FmRolodex::PORTAL_FIELDS maps to a
  #                        person (including its sector/age tags and the archive's own
  #                        entry date), plus the row's primary address and phone
  #   * linked           — the person PersonMatcher finds for the row's name + email —
  #                        which reaches their secondary and login addresses too — gets
  #                        the row's ID as their filemaker_code
  #   * already_imported — a person already carries the row's ID
  #   * ambiguous        — a name or email collides with someone we can't safely
  #                        claim is the same person; reconcile by hand
  #   * skipped          — agency, soft-deleted, or nameless rows
  #   * failed           — the Person didn't validate
  #
  # A row whose email matches nobody is created even when someone already shares the
  # name: folding the occasional duplicate with the person deduper beats hand-resolving
  # every name collision in a 39,000-row archive.
  class ImportFromRolodex
    OUTCOMES = %i[created linked already_imported ambiguous skipped failed].freeze
    FALSE_FLAGS = %w[0 n no false].freeze
    DATE_FORMATS = %w[%m/%d/%Y %Y-%m-%d %m-%d-%Y %Y/%m/%d].freeze
    # A two-digit year below this is read as 20xx, at or above it as 19xx.
    TWO_DIGIT_YEAR_PIVOT = 10
    CONTACT_TYPES = { "home" => "personal", "personal" => "personal", "cell" => "personal",
                      "mobile" => "personal", "work" => "work", "mailing" => "mailing" }.freeze
    EMAIL_PATTERN = /[^\s,;<>"']+@[^\s,;<>"']+\.[^\s,;<>"']+/
    UNKNOWN_LOCALITY = "Unknown"
    STRING_LIMIT = 255

    attr_reader :results, :unmatched_tags

    def initialize(scope: FmRolodex.all)
      @scope = scope
      @results = OUTCOMES.index_with { [] }
      @imported_codes = Person.where.not(filemaker_code: [ nil, "" ]).pluck(:filemaker_code)
                              .flat_map { |value| Person.split_filemaker_codes(value) }.to_set
      @sectors_by_name = name_index(Sector.all)
      @age_groups_by_name = name_index(Category.age_ranges)
      @unmatched_tags = Hash.new(0)
    end

    def call
      @scope.find_each { |rolodex| import(rolodex) }
      self
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
        return link(match.first, rolodex, label) if match.one?
        return record(:ambiguous, "#{label}: #{match.size} people share this name and email (#{ids(match)})") if match.many?

        others = Person.where("LOWER(email) = :email OR LOWER(email_2) = :email", email: email.downcase).to_a
        return record(:ambiguous, "#{label}: #{email} belongs to #{others.map { |p| "##{p.id} #{p.full_name}" }.join(', ')}") if others.any?
      else
        no_email = Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", first_name.downcase, last_name.downcase)
                         .where(email: [ nil, "" ]).to_a
        return record(:ambiguous, "#{label}: no email, same name as #{ids(no_email)}") if no_email.any?
      end

      create(rolodex, label, first_name:, last_name:, email:, email_2:)
    end

    def link(person, rolodex, label)
      if person.filemaker_code.present?
        return record(:ambiguous, "#{label}: matches ##{person.id}, already linked to FileMaker #{person.filemaker_code}")
      end

      return record(:failed, "#{label}: ##{person.id} #{person.errors.full_messages.to_sentence}") unless person.update(filemaker_code: rolodex.fm_id)

      @imported_codes << rolodex.fm_id
      record(:linked, "#{label} → ##{person.id}")
    end

    def create(rolodex, label, **names)
      data = rolodex.data
      person = Person.new(
        **names,
        filemaker_code: rolodex.fm_id,
        pronouns: clip(data["Pronouns"]),
        best_time_to_call: clip(data["BestTimeToCall"]),
        racial_ethnic_identity: clip(data["Ethnicity"]),
        date_of_birth: parse_date(data["DateOfBirth"]),
        email_type: email_type(data["EmailType"]),
        member_since: member_since(data),
        notes: data["Comments"].presence,
        **archive_timestamps(data)
      )
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

    # The archive's service areas and age group tag the person through the same seam a
    # submission uses — additive, since the import is never the whole picture.
    def tag_service_areas(person, data)
      SubmissionTagging.apply(person:, organizations: [], tag_with: :tag_sectors,
                              primary_ids: tag_ids(data["PrimaryServiceArea"], @sectors_by_name).first(1),
                              additional_ids: tag_ids(data["OtherServiceArea"], @sectors_by_name))
      SubmissionTagging.apply(person:, organizations: [], tag_with: :tag_age_groups,
                              primary_ids: tag_ids(data["PrimaryAgeGroup"], @age_groups_by_name))
    end

    # One field can list several areas. Each resolves by name, then by the portal's
    # qualified form of it ("Child Abuse" → "Child Abuse/Neglect"); a name nothing
    # answers to is counted in #unmatched_tags rather than guessed at.
    def tag_ids(value, index)
      value.to_s.split(/[,;]/).map { |name| name.strip.downcase }.reject(&:empty?).uniq.filter_map do |name|
        id = index[name] || index.find { |stored, _| stored.start_with?("#{name}/") }&.last
        @unmatched_tags[name] += 1 unless id
        id
      end
    end

    def name_index(scope)
      scope.pluck(:name, :id).to_h { |name, id| [ name.to_s.strip.downcase, id ] }
    end

    # Every address the row answers to, not just the one it names as primary —
    # FmRolodex#addresses lists them with the primary and worksite ones first, so the
    # first that can be built is the person's primary and the rest ride along.
    def build_addresses(person, rolodex)
      attributes = rolodex.addresses.filter_map { |address| address_attributes(address.data) }
      attributes.each_with_index { |attrs, index| person.addresses.build(attrs.merge(primary: index.zero?)) }
    end

    def build_phones(person, rolodex)
      attributes = rolodex.phone_numbers.filter_map { |phone| phone_attributes(phone.data) }
      attributes.each_with_index { |attrs, index| person.contact_methods.build(attrs.merge(primary: index.zero?)) }
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
