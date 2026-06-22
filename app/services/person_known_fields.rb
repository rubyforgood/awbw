# Maps a person's already-on-file identity and contact data onto the registration
# form's `logged_out_only` field identifiers.
#
# Used by EventRegistrationServices::PublicRegistration to backfill a signed-in
# registrant's answers: those `logged_out_only` fields are hidden from the form
# (see PublicRegistrationsController#hide_logged_out_only_fields) and so never
# reach the submitted params, but whatever we already have on file should still
# be recorded on the submission so it's a complete snapshot rather than silently
# omitting them.
#
# A "nickname" value is only carried when a real preferred name exists (otherwise
# it maps to the legal first name, which belongs to the "first_name" field); the
# backfill skips blank values either way.
class PersonKnownFields
  def self.call(person)
    new(person).call
  end

  def initialize(person)
    @person = person
  end

  def call
    return {} unless @person

    fields = {}
    fields["first_name"] = legal_first_name if @person.first_name.present?
    fields["last_name"] = @person.last_name if @person.last_name.present?
    if @person.email.present?
      fields["primary_email"] = @person.email
      fields["confirm_email"] = @person.email
    end
    fields["primary_email_type"] = humanize_type(@person.email_type) if @person.email_type.present?
    # The "Preferred Nickname" field maps to first_name, but only when a real
    # nickname exists (resolve_names then stores the legal name on legal_first_name).
    fields["nickname"] = @person.first_name if @person.legal_first_name.present?
    fields["pronouns"] = @person.pronouns if @person.pronouns.present?
    fields["secondary_email"] = @person.email_2 if @person.email_2.present?
    fields["secondary_email_type"] = humanize_type(@person.email_2_type) if @person.email_2_type.present?
    add_address(fields)
    add_phone(fields)
    fields
  end

  private

  # The "First Name" field collects the legal first name; resolve_names stores it
  # on legal_first_name when a nickname was given, otherwise on first_name.
  def legal_first_name
    @person.legal_first_name.presence || @person.first_name
  end

  def add_address(fields)
    return unless @person.addresses.exists?

    address = @person.addresses.find_by(primary: true) || @person.addresses.first
    fields["mailing_street"] = address.street_address if address.street_address.present?
    fields["mailing_address_type"] = humanize_type(address.address_type) if address.address_type.present?
    fields["mailing_city"] = address.city if address.city.present?
    fields["mailing_state"] = address.state if address.state.present?
    fields["mailing_zip"] = address.zip_code if address.zip_code.present?
  end

  def add_phone(fields)
    phones = @person.contact_methods.where(kind: :phone)
    return unless phones.exists?

    phone = phones.find_by(primary: true) || phones.first
    fields["phone"] = phone.value
    fields["phone_type"] = humanize_type(phone.contact_type)
  end

  # The *_type selector options are capitalized labels ("Personal" / "Work"),
  # while the underlying columns store them lowercased.
  def humanize_type(value)
    value.to_s.capitalize.presence
  end
end
