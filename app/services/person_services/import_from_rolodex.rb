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
  class ImportFromRolodex
    OUTCOMES = %i[created linked already_imported ambiguous skipped failed].freeze
    FALSE_FLAGS = %w[0 n no false].freeze
    DATE_FORMATS = %w[%m/%d/%Y %Y-%m-%d].freeze
    CONTACT_TYPES = { "home" => "personal", "personal" => "personal", "work" => "work", "mailing" => "mailing" }.freeze
    EMAIL_PATTERN = /[^\s,;<>"']+@[^\s,;<>"']+\.[^\s,;<>"']+/
    UNKNOWN_LOCALITY = "Unknown"

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
        pronouns: data["Pronouns"].presence,
        best_time_to_call: data["BestTimeToCall"].presence,
        racial_ethnic_identity: data["Ethnicity"].presence,
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

      street = [ fields["AddrsLine1"], fields["AddrsLine2"] ].filter_map { |line| line.to_s.strip.presence }.join(", ")
      city = fields["AddrsCity"].to_s.strip
      state = fields["AddrsState"].to_s.strip
      return if street.blank? || city.blank? || state.blank?

      {
        street_address: street,
        city:,
        state:,
        zip_code: fields["AddrsPostalCode"].to_s.strip,
        country: fields["AddrsCountry"].presence,
        address_type: contact_type(fields["AddrsType"]),
        locality: UNKNOWN_LOCALITY,
        primary: true
      }
    end

    def phone_attributes(fm_id)
      fields = fm_id.presence && FmPhoneNumber.find_by(fm_id:)&.data
      number = fields && fields["PhoneNumber"].to_s.strip
      return if number.blank?

      { kind: "phone", value: number, contact_type: contact_type(fields["PhoneType"]), primary: true }
    end

    def contact_type(value)
      CONTACT_TYPES[value.to_s.strip.downcase]
    end

    def parse_date(value)
      value = value.to_s.strip
      return if value.blank?

      DATE_FORMATS.each do |format|
        return Date.strptime(value, format)
      rescue Date::Error
        next
      end
      nil
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
