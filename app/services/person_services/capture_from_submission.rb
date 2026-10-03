module PersonServices
  # Fills a Person's profile and contact details from a submitted form. The same
  # capture runs whether the submission is an event registration or a standalone
  # form, and whether the person is newly created or already on file, so the smart
  # fields documented on the Smart field settings page behave identically across
  # both forms.
  #
  # A non-blank answer overwrites what's on file — the newest submission is treated
  # as the freshest source of truth — and a blank answer never clears existing
  # data. Every write lands on the record, so AhoyTrackable logs it and the
  # submission's "what this submission changed" page picks it up.
  #
  # Reads its answers straight from the form + params (self-gating on each field
  # identifier), so a form that doesn't ask a given question is simply a no-op for
  # it. Sector/age tags are mirrored onto any organizations passed in.
  class CaptureFromSubmission
    def self.call(person:, form:, form_params: {}, organizations: [])
      new(person:, form:, form_params:, organizations:).call
    end

    def initialize(person:, form:, form_params: {}, organizations: [])
      @person = person
      @form = form
      @form_params = (form_params || {}).transform_keys(&:to_s)
      @organizations = Array(organizations).compact
    end

    def call
      apply_nickname
      apply_value(@person, :pronouns, field_value("pronouns"))
      apply_value(@person, :pronunciation, field_value("pronunciation"))
      apply_value(@person, :email_type, field_value("primary_email_type")&.downcase)
      apply_value(@person, :email_2, field_value("secondary_email"))
      apply_value(@person, :email_2_type, field_value("secondary_email_type")&.downcase)
      apply_value(@person, :racial_ethnic_identity, field_value("racial_ethnic_identity"))
      PersonServices::SyncSharingPreferences.call(person: @person, form: @form, form_params: @form_params)
      capture_mailing_address
      capture_phone
      apply_tags
      @person
    end

    private

    # A nickname becomes the person's first name and moves the legal first name to
    # its own column, matching how a new registrant's name is resolved at sign-up.
    def apply_nickname
      nickname = field_value("nickname")&.strip
      return if nickname.blank?

      @person.update!(first_name: nickname)
      apply_value(@person, :legal_first_name, field_value("first_name"))
    end

    def apply_value(record, attribute, value)
      return if value.blank?
      record.update!(attribute => value.strip)
    end

    def field_value(key)
      field = @form.form_fields.find_by(field_identifier: key)
      return nil unless field
      @form_params[field.id.to_s]
    end

    def capture_mailing_address
      new_city = field_value("mailing_city")&.strip
      return if new_city.blank?

      new_state = field_value("mailing_state")&.strip
      existing = @person.addresses.find_by(
        "LOWER(city) = ? AND LOWER(COALESCE(state, '')) = ?",
        new_city.downcase, new_state&.downcase.to_s
      )

      if existing
        existing.update!(
          street_address: field_value("mailing_street"),
          zip_code: field_value("mailing_zip"),
          primary: true,
          inactive: false
        )
        apply_value(existing, :country, field_value("mailing_country"))
        apply_value(existing, :address_type, field_value("mailing_address_type")&.downcase)
        return existing
      end

      @person.addresses.where(primary: true).update_all(primary: false, inactive: true)

      @person.addresses.create!(
        street_address: field_value("mailing_street"),
        city: new_city,
        state: new_state,
        zip_code: field_value("mailing_zip"),
        country: field_value("mailing_country")&.strip,
        locality: "Unknown",
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

    def apply_tags
      primary_sector_ids = collect_ids(FormField::PRIMARY_SECTOR_FIELD_IDENTIFIERS)
      additional_sector_ids = collect_ids(FormField::ADDITIONAL_SECTOR_FIELD_IDENTIFIERS)
      primary_age_ids = collect_ids(FormField::PRIMARY_AGE_GROUP_FIELD_IDENTIFIERS)
      additional_age_ids = collect_ids(FormField::ADDITIONAL_AGE_GROUP_FIELD_IDENTIFIERS)

      # Only a primary answer → reassign the primary but keep the rest (additive).
      # Both primary and additional → the submission is the whole picture, so
      # overwrite the person's set. The org mirror always stays additive (orgs
      # aggregate their members' tags).
      if primary_sector_ids.any? || additional_sector_ids.any?
        SectorTagging.apply(person: @person, organizations: @organizations,
                            primary_ids: primary_sector_ids, additional_ids: additional_sector_ids,
                            replace_person: primary_sector_ids.any? && additional_sector_ids.any?)
      end

      if primary_age_ids.any? || additional_age_ids.any?
        @person.tag_age_groups(primary_ids: primary_age_ids, additional_ids: additional_age_ids,
                               replace: primary_age_ids.any? && additional_age_ids.any?)
        @organizations.each { |org| org.tag_age_groups(primary_ids: primary_age_ids, additional_ids: additional_age_ids) }
      end
    end

    def collect_ids(identifiers)
      identifiers.flat_map do |identifier|
        field = @form.form_fields.find_by(field_identifier: identifier)
        next [] unless field
        Array(@form_params[field.id.to_s]).reject(&:blank?).map(&:to_i)
      end
    end
  end
end
