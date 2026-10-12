module PersonServices
  # Turns FileMaker Rolodex archive rows (FmRolodex) into people. Each row lands in
  # one outcome bucket of #results:
  #   * created          — new Person, with the row's primary address and phone
  #   * linked           — an existing person with the same name + email gets the
  #                        row's ID as their filemaker_code
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

    attr_reader :results

    def initialize(scope: FmRolodex.all)
      @scope = scope
      @results = OUTCOMES.index_with { [] }
      @imported_codes = Person.where.not(filemaker_code: [ nil, "" ]).pluck(:filemaker_code).map(&:strip).to_set
    end

    def call
      @scope.find_each { |rolodex| import(rolodex) }
      self
    end

    private

    def import(rolodex)
      data = rolodex.data
      first_name = data["FirstName"].to_s.strip
      last_name = data["LastName"].to_s.strip
      label = "#{rolodex.fm_id} #{first_name} #{last_name}".squish

      return record(:already_imported, label) if @imported_codes.include?(rolodex.fm_id)
      return record(:skipped, "#{label}: agency") if flag?(data["isAgency__c"])
      return record(:skipped, "#{label}: marked deleted") if flag?(data["Delete"])
      return record(:skipped, "#{label}: missing first or last name") if first_name.blank? || last_name.blank?

      email, email_2 = data["EMail"].to_s.scan(EMAIL_PATTERN)
      same_name = Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", first_name.downcase, last_name.downcase)

      if email
        match = same_name.where("LOWER(email) = :email OR LOWER(email_2) = :email", email: email.downcase).to_a
        return link(match.first, rolodex, label) if match.one?
        return record(:ambiguous, "#{label}: #{match.size} people share this name and email (#{ids(match)})") if match.many?

        others = Person.where("LOWER(email) = :email OR LOWER(email_2) = :email", email: email.downcase).to_a
        return record(:ambiguous, "#{label}: #{email} belongs to #{others.map { |p| "##{p.id} #{p.full_name}" }.join(', ')}") if others.any?
      else
        no_email = same_name.where(email: [ nil, "" ]).to_a
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
        notes: data["Comments"].presence
      )
      address = address_attributes(data["PrimaryAddrsID"])
      person.addresses.build(address) if address
      phone = phone_attributes(data["PrimaryPhoneID"])
      person.contact_methods.build(phone) if phone

      return record(:failed, "#{label}: #{person.errors.full_messages.to_sentence}") unless person.save

      @imported_codes << rolodex.fm_id
      record(:created, "#{label} → ##{person.id}")
    end

    def address_attributes(fm_id)
      fields = fm_id.presence && FmAddress.find_by(fm_id:)&.data
      return unless fields

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
        locality: UNKNOWN_LOCALITY,
        primary: true
      }
    end

    def phone_attributes(fm_id)
      fields = fm_id.presence && FmPhoneNumber.find_by(fm_id:)&.data
      number = fields && fields["PhoneNumber"].to_s.strip
      return if number.blank?

      { kind: "phone", value: number, contact_type: contact_type(fields["PhoneType"], allowed: ContactMethod::CONTACT_TYPES), primary: true }
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
