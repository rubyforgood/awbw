module PersonServices
  # Fills a Person's profile and contact details from a submitted form. The same
  # capture runs whether the submission is an event registration or a standalone
  # form, and whether the person is newly created or already on file, so the smart
  # fields documented on the Smart field settings page behave identically across
  # both forms.
  #
  # In every flow (public forms and the spreadsheet import) a non-blank answer
  # overwrites what's on file — the newest answer wins — and a blank answer never
  # clears existing data. Every write lands on the record, so AhoyTrackable logs it
  # (the prior value is recoverable there) and the submission's "what this
  # submission changed" page picks it up.
  #
  # Reads its answers straight from the form + params (self-gating on each field
  # identifier), so a form that doesn't ask a given question is simply a no-op for
  # it.
  #
  # `answers` (field_identifier => value) stands in for form + form_params when the
  # values come from somewhere other than a submitted form, e.g. a spreadsheet import.
  class CaptureFromSubmission
    # A saved value an answer replaced, so a caller (the import) can tell staff
    # what changed and they can reapply a newer edit.
    Replaced = Struct.new(:label, :submitted, :saved, keyword_init: true)

    attr_reader :replaced

    def self.call(person:, form: nil, form_params: {}, answers: nil)
      new(person:, form:, form_params:, answers:).call
    end

    def initialize(person:, form: nil, form_params: {}, answers: nil)
      @person = person
      @form = form
      @form_params = (form_params || {}).transform_keys(&:to_s)
      @answers = answers&.transform_keys(&:to_s)
      @replaced = []
    end

    def call
      apply_legal_first_name(field_value("legal_first_name"))
      apply_value(@person, :pronouns, field_value("pronouns"))
      apply_value(@person, :pronunciation, field_value("pronunciation"))
      apply_value(@person, :email_type, field_value("primary_email_type")&.downcase)
      apply_value(@person, :email_2, field_value("secondary_email"))
      apply_value(@person, :email_2_type, field_value("secondary_email_type")&.downcase)
      apply_value(@person, :racial_ethnic_identity, field_value("racial_ethnic_identity"))
      PersonServices::SyncSharingPreferences.call(person: @person, form: @form, form_params: @form_params) if @form
      capture_mailing_address
      capture_phone
      capture_license
      apply_tags
      @person
    end

    private

    # Recorded only when it differs from the first name, so a matching answer never displaces a legal name on file.
    def apply_legal_first_name(value)
      return unless @person.legal_first_name_differs?(value)

      apply_value(@person, :legal_first_name, value)
    end

    def apply_value(record, attribute, value)
      return if value.blank?

      saved = record.public_send(attribute)
      record.update!(attribute => value.strip)
      note_replaced(record, attribute, value.strip, saved)
    end

    def note_replaced(record, attribute, submitted, saved)
      return if saved.blank? || submitted.casecmp?(saved.to_s.strip)

      label = record == @person ? attribute.to_s.humanize : "Mailing address #{attribute.to_s.humanize.downcase}"
      @replaced << Replaced.new(label: label, submitted: submitted, saved: saved)
    end

    def field_value(key)
      return @answers[key] if @answers

      field = @form.form_fields.find_by(field_identifier: key)
      return nil unless field
      @form_params[field.id.to_s]
    end

    def capture_mailing_address
      new_city = field_value("mailing_city")&.strip
      return if new_city.blank?

      new_state = field_value("mailing_state")&.strip
      new_country = field_value("mailing_country")&.strip
      existing = @person.addresses.order(:id).find do |address|
        AddressNormalizer.city(address.city) == AddressNormalizer.city(new_city) &&
          AddressNormalizer.state(address.state) == AddressNormalizer.state(new_state)
      end

      if existing
        apply_value(existing, :street_address, field_value("mailing_street"))
        apply_value(existing, :zip_code, field_value("mailing_zip"))
        existing.update!(primary: true, inactive: false)
        apply_value(existing, :country, new_country)
        apply_value(existing, :address_type, field_value("mailing_address_type")&.downcase)
        return existing
      end

      @person.addresses.where(primary: true).update_all(primary: false, inactive: true)

      @person.addresses.create!(
        # street/ZIP are NOT NULL with no default, so a skipped answer lands as "".
        street_address: field_value("mailing_street").to_s,
        city: new_city,
        state: new_state,
        zip_code: field_value("mailing_zip").to_s,
        **AddressDefaults.for(city: new_city, state: new_state, zip_code: field_value("mailing_zip"), country: new_country),
        address_type: field_value("mailing_address_type")&.downcase || "unknown",
        primary: true
      )
    end

    def capture_phone
      phone_value = field_value("phone")&.strip
      return if phone_value.blank?

      phone_type = field_value("phone_type")&.downcase
      contact_type = phone_type == "work" ? "work" : "personal"

      existing = @person.contact_methods.find_by(kind: :phone, value: phone_value)

      if existing
        existing.update!(contact_type: contact_type, primary: true, inactive: false)
        return existing
      end

      @person.contact_methods.where(kind: :phone, primary: true).update_all(primary: false, inactive: true)

      @person.contact_methods.create!(
        kind: :phone,
        value: phone_value,
        contact_type: contact_type,
        primary: true
      )
    end

    # A license is identified by its number (plus type), so no number answered means
    # no license saved. Not every license is for CE: these plain license_* answers only
    # record it on the person's profile. CE enrollment reads the ce_license_* answers
    # on the event's CE form instead (ContinuingEducationRegistration.enroll!).
    def capture_license
      number = field_value("license_number")&.strip
      return if number.blank?

      license = find_or_add_license(*ProfessionalLicense.split_kind_from_number(kind: field_value("license_kind")&.strip, number:))
      apply_value(license, :issuing_state, field_value("license_issuing_state"))
      apply_value(license, :issuing_country, field_value("license_issuing_country"))
      apply_value(license, :expires_on, field_value("license_expires_on"))
      license
    end

    # The same license already on file (an untyped answer matches the number under
    # any type), else the number-pending placeholder a CE opt-in left, else a new one.
    def find_or_add_license(kind, number)
      licenses = @person.professional_licenses
      kind = kind.presence
      licenses.find_by(number:, kind:) ||
        (licenses.find_by(number:) unless kind) ||
        licenses.find_by(number: nil)&.tap { |placeholder| placeholder.update!(number:, kind: kind || placeholder.kind) } ||
        licenses.create!(number:, kind:)
    end

    def apply_tags
      apply_tag_set(FormField::PRIMARY_SECTOR_FIELD_IDENTIFIERS,
                    FormField::ADDITIONAL_SECTOR_FIELD_IDENTIFIERS, :tag_sectors)
      apply_tag_set(FormField::PRIMARY_AGE_GROUP_FIELD_IDENTIFIERS,
                    FormField::ADDITIONAL_AGE_GROUP_FIELD_IDENTIFIERS, :tag_age_groups)
    end

    # Only a primary answer → reassign the primary but keep the rest (additive).
    # Both primary and additional → the submission is the whole picture, so
    # overwrite the person's set.
    def apply_tag_set(primary_identifiers, additional_identifiers, tag_with)
      primary_ids = collect_ids(primary_identifiers)
      additional_ids = collect_ids(additional_identifiers)
      return if primary_ids.empty? && additional_ids.empty?

      @person.public_send(tag_with, primary_ids: primary_ids, additional_ids: additional_ids,
                                    replace: primary_ids.any? && additional_ids.any?)
    end

    def collect_ids(identifiers)
      identifiers.flat_map do |identifier|
        Array(field_value(identifier)).reject(&:blank?).map(&:to_i)
      end
    end
  end
end
