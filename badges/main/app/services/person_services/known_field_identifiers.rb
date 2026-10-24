module PersonServices
  # The smart-field identifiers this person's profile already answers, so a form can
  # skip its "Logged out only" questions for them.
  class KnownFieldIdentifiers
    def self.call(person)
      new(person).call
    end

    def initialize(person)
      @person = person
    end

    def call
      keys = []
      keys << "first_name" if @person.first_name.present?
      keys << "last_name" if @person.last_name.present?
      keys << "primary_email" << "confirm_email" if @person.email.present?
      keys << "primary_email_type" if @person.known_email_type?
      keys << "legal_first_name" if @person.legal_first_name.present?
      keys << "pronouns" if @person.pronouns.present?
      keys << "secondary_email" if @person.email_2.present?
      keys << "secondary_email_type" if @person.known_email_2_type?
      keys.concat(address_keys)
      keys << "phone" << "phone_type" if @person.contact_methods.where(kind: :phone).exists?
      keys
    end

    private

    def address_keys
      address = @person.addresses.find_by(primary: true) || @person.addresses.first
      return [] unless address

      keys = []
      keys << "mailing_street" if address.street_address.present?
      keys << "mailing_address_type" if address.known_type?
      keys << "mailing_city" if address.city.present?
      keys << "mailing_state" if address.state.present?
      keys << "mailing_zip" if address.zip_code.present?
      keys
    end
  end
end
