module EventRegistrationServices
  class PublicRegistration
    Result = Struct.new(:success?, :event_registration, :form_submission, :errors, keyword_init: true)

    # Well-known field_identifier of the "magic" CE question seeded onto the
    # registration form. Answering it "Yes" creates a ContinuingEducationRegistration
    # (hours come from the event). Kept here so the seed, service, and specs agree.
    CE_CREDIT_INTEREST_IDENTIFIER = "ce_credit_interest".freeze

    # Well-known field_identifier of the CE license-number question. Its answer
    # seeds the registrant's ProfessionalLicense.
    CE_LICENSE_NUMBER_IDENTIFIER = "ce_license_number".freeze

    # Well-known field_identifier of the CE license-type question (e.g. "LCSW").
    # Its answer seeds the ProfessionalLicense's kind.
    CE_LICENSE_KIND_IDENTIFIER = "ce_license_kind".freeze

    # Well-known field_identifiers of the CE license issuing-state and expiry
    # questions. Their answers fill in the ProfessionalLicense's issuing_state
    # and expires_on (both optional — registrants can supply them later).
    CE_LICENSE_ISSUING_STATE_IDENTIFIER = "ce_license_issuing_state".freeze
    CE_LICENSE_EXPIRES_ON_IDENTIFIER = "ce_license_expires_on".freeze

    # Well-known field_identifier of the "Additional forms" multi-select question.
    # Checking "Invoice" / "W-9" toggles the registration's invoice_requested /
    # w9_requested flags, which the digital ticket reads to surface those downloads.
    # The option labels below must match the seeded answer options exactly.
    ADDITIONAL_FORMS_IDENTIFIER = "additional_forms".freeze
    ADDITIONAL_FORMS_INVOICE = "Invoice".freeze
    ADDITIONAL_FORMS_W9 = "W-9".freeze

    # Well-known field_identifiers for the registrant's organization name and
    # position on the registration form. We name them in organization terms here
    # as we move the vocabulary away from "agency"; the stored identifiers are
    # still "agency_*" pending a form-field rename. Kept here so the service,
    # controller, and specs agree on a single source.
    ORGANIZATION_NAME_IDENTIFIER = "agency_name".freeze
    ORGANIZATION_POSITION_IDENTIFIER = "agency_position".freeze

    def self.call(event:, registration_form:, form_params:, scholarship_requested: false, person: nil,
                  scholarship_form: nil, scholarship_params: {},
                  continuing_education_form: nil, continuing_education_params: {})
      new(event:, registration_form:, form_params:, scholarship_requested:, person:,
          scholarship_form:, scholarship_params:,
          continuing_education_form:, continuing_education_params:).call
    end

    def initialize(event:, registration_form:, form_params:, scholarship_requested: false, person: nil,
                   scholarship_form: nil, scholarship_params: {},
                   continuing_education_form: nil, continuing_education_params: {})
      @event = event
      @registration_form = registration_form
      @form_params = form_params
      @scholarship_requested = scholarship_requested
      @person = person
      @scholarship_form = scholarship_form
      @scholarship_params = scholarship_params || {}
      @continuing_education_form = continuing_education_form
      @continuing_education_params = continuing_education_params || {}
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        person = find_or_create_person
        sync_person_profile(person)
        record_mailing_list_consent(person)

        create_mailing_address(person) if field_value("mailing_city").present?
        create_phone_contact(person) if field_value("phone").present?

        organization = find_organization if field_value(ORGANIZATION_NAME_IDENTIFIER).present?
        if organization
          sync_organization_profile(organization)
          agency_address = create_agency_address(organization)
          create_affiliation(person, organization, agency_address)
        end

        assign_tags(person, organization)

        existing = @event.event_registrations.find_by(registrant: person)
        if existing
          existing.update!(scholarship_requested: true) if @scholarship_requested
          create_ce_registration(existing, person)
          existing.update!(w9_requested: true) if w9_requested?
          existing.update!(invoice_requested: true) if invoice_requested?
          payment_method = field_value("payment_method")&.strip
          existing.update!(expected_payment_method: payment_method) if payment_method.present?
          if existing.status == "cancelled"
            existing.update!(status: "registered")
            send_notifications(existing)
          end
          connect_organization(existing, organization)
          submission = update_form_submission(person)
          save_scholarship_submission(person)
          save_continuing_education_submission(person)
          return Result.new(success?: true, event_registration: existing, form_submission: submission, errors: [])
        end

        event_registration = create_event_registration(person)
        create_ce_registration(event_registration, person)
        connect_organization(event_registration, organization)
        submission = create_form_submission(person)
        save_scholarship_submission(person)
        save_continuing_education_submission(person)

        send_notifications(event_registration)

        Result.new(success?: true, event_registration: event_registration, form_submission: submission, errors: [])
      end
    rescue ActiveRecord::ValueTooLong => e
      Result.new(success?: false, event_registration: nil, errors: [ too_long_message(e) ])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, event_registration: nil, errors: [ e.message ])
    rescue ActiveRecord::RecordNotUnique => e
      if e.message.include?("registrant_id")
        Result.new(success?: false, event_registration: nil,
                   errors: [ "You are already registered for this event." ])
      else
        Result.new(success?: false, event_registration: nil, errors: [ e.message ])
      end
    end

    private

    # Turn a database "Data too long for column 'city'" failure into a friendly,
    # form-level message. We can't always map the column back to a single form
    # field (both the mailing and agency address write `city`), so we name the
    # column generically and ask the registrant to shorten that answer.
    def too_long_message(error)
      column = error.message[/column '([^']+)'/, 1]
      return "One of your answers is too long. Please shorten it and try again." if column.blank?

      "Your #{column.humanize.downcase} is too long. Please shorten it and try again."
    end

    def field_value(key)
      field = @registration_form.form_fields.find_by(field_identifier: key)
      return nil unless field
      @form_params[field.id.to_s]
    end

    def resolve_names
      submitted_first = field_value("first_name")&.strip
      nickname = field_value("nickname")&.strip

      if nickname.present?
        { first_name: nickname, legal_first_name: submitted_first }
      else
        { first_name: submitted_first, legal_first_name: nil }
      end
    end

    def find_or_create_person
      return @person if @person

      names = resolve_names
      first_name = names[:first_name]
      last_name = field_value("last_name")&.strip
      email = field_value("primary_email")&.strip&.downcase
      email_type = field_value("primary_email_type")&.downcase

      person = find_matching_person(last_name: last_name, email: email)
      return person if person

      Person.create!(
        first_name: first_name,
        legal_first_name: names[:legal_first_name],
        last_name: last_name,
        pronouns: field_value("pronouns")&.strip,
        email: email,
        email_type: email_type,
        email_2: field_value("secondary_email")&.strip,
        email_2_type: field_value("secondary_email_type")&.downcase,
      )
    end

    # Find the existing registrant this submission belongs to, tolerating a
    # first-name / nickname swap. We match on email + last name (both strong,
    # stable identifiers) and accept either the typed first name or the nickname
    # against either the stored first_name or legal_first_name. Without this, a
    # returning registrant who types their legal name when we stored their
    # nickname (or vice versa) slips past the match and registers as a duplicate
    # Person. Anonymous (incognito) registrations rely on this; logged-in ones
    # already arrive with @person set and never reach here.
    def find_matching_person(last_name:, email:)
      return if email.blank? || last_name.blank?

      first_names = [ field_value("first_name"), field_value("nickname") ]
        .filter_map { |value| value&.strip.presence&.downcase }
        .uniq
      return if first_names.empty?

      Person
        .where("LOWER(last_name) = ? AND LOWER(email) = ?", last_name.downcase, email.downcase)
        .where("LOWER(first_name) IN (:names) OR LOWER(COALESCE(legal_first_name, '')) IN (:names)", names: first_names)
        .first
    end

    # Populate the structured columns that the registration form collects but that
    # we historically stored only as form answers. A non-blank submitted value
    # overwrites whatever was on file: the latest registration is treated as the
    # freshest source of truth, and the prior value is preserved in the audit trail
    # — every model includes AhoyTrackable, whose after_update logs an Ahoy::Event
    # capturing the change. A blank answer never clobbers existing data.
    def sync_person_profile(person)
      apply_value(person, :racial_ethnic_identity, field_value("racial_ethnic_identity"))
    end

    def sync_organization_profile(organization)
      apply_value(organization, :website_url, field_value("agency_website"))
      sync_agency_type(organization)
    end

    # The "Organization Type" answer folds an "Other" choice's free text in as
    # "Other: <text>" (a specify option). Split the option label from the typed
    # text: the label drives agency_type and the stripped text fills
    # agency_type_other, which is cleared for the non-"Other" classifications so
    # no stale free text lingers. Follows the same latest-wins / never-clobber-on-
    # blank contract as apply_value.
    def sync_agency_type(organization)
      raw = field_value("agency_type")&.strip
      return if raw.blank?

      label, _separator, specified = raw.partition(":")
      label = label.strip
      return if label.blank?
      other_text = FormField.other_option?(label) ? specified.strip.presence : nil
      organization.update!(agency_type: label, agency_type_other: other_text)
      capture_organization_type_other(organization, other_text)
    end

    # Materialize the org-type "Other" as an OtherResponse owned by the org, so it
    # joins the curation queue alongside sector "Other"s. Not promotable yet (no
    # OrganizationType model), but stored now so nothing is lost; de-duped per org.
    def capture_organization_type_other(organization, text)
      return if text.blank?

      organization.other_responses.find_or_create_by!(
        field_identifier: OtherResponse::ORGANIZATION_TYPE_FIELD_IDENTIFIER,
        normalized_text: OtherResponse.normalize(text)
      ) { |response| response.text = text }
    end

    # Write value onto attribute when a non-blank value was submitted, overwriting
    # any existing value. A no-op when the value is unchanged (update! records no
    # change, so no spurious audit event).
    def apply_value(record, attribute, value)
      return if value.blank?
      record.update!(attribute => value.strip)
    end

    # Consent is opt-in only and recorded once. An affirmative answer grants
    # consent (stamping the time and where it came from) when none is on file; we
    # never clear it from here — withdrawal is a separate, deliberate action — and
    # we don't keep re-stamping a registrant who already consented.
    def record_mailing_list_consent(person)
      return if person.mailing_list_consent_at.present?
      return unless mailing_list_consent_given?

      person.update!(
        mailing_list_consent_at: Time.current,
        mailing_list_consent_source: mailing_list_consent_source
      )
    end

    def mailing_list_consent_given?
      Array(field_value("communication_consent")).any? { |value| value.to_s.strip.present? }
    end

    # Identify the event by start date *and* title — many trainings share a title,
    # so the leading date is what makes the consent source traceable to one event,
    # e.g. "2026-06-23 Facilitator Training registration".
    def mailing_list_consent_source
      [ @event.start_date&.to_date&.iso8601, "#{@event.title} registration" ].compact.join(" ")
    end

    def create_mailing_address(person)
      new_city = field_value("mailing_city")&.strip
      new_state = field_value("mailing_state")&.strip

      existing = person.addresses.find_by(
        "LOWER(city) = ? AND LOWER(COALESCE(state, '')) = ?",
        new_city&.downcase, new_state&.downcase.to_s
      )

      if existing
        existing.update!(
          street_address: field_value("mailing_street"),
          zip_code: field_value("mailing_zip"),
          primary: true,
          inactive: false
        )
        apply_value(existing, :country, field_value("mailing_country"))
        return existing
      end

      person.addresses.where(primary: true).update_all(primary: false, inactive: true)

      person.addresses.create!(
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

    def create_phone_contact(person)
      phone_value = field_value("phone")&.strip
      phone_type = field_value("phone_type")&.downcase
      contact_type = phone_type == "work" ? "work" : "personal"

      existing = person.contact_methods.find_by(kind: :phone, value: phone_value)

      if existing
        existing.update!(
          contact_type: contact_type,
          primary: true,
          inactive: false
        )
        return existing
      end

      person.contact_methods.where(kind: :phone, primary: true).update_all(primary: false, inactive: true)

      person.contact_methods.create!(
        kind: :phone,
        value: phone_value,
        contact_type: contact_type,
        primary: true
      )
    end

    def find_organization
      name = field_value(ORGANIZATION_NAME_IDENTIFIER)&.strip
      return nil if name.blank?

      Organization.find_by(name: name)
    end

    # Connect only the one organization the registrant submitted on this form —
    # not every organization they're affiliated with. A registration accrues
    # multiple orgs only deliberately: an admin links extra ones from the edit
    # page, or the registrant applies again with a different org (each submission
    # adds its single org to the same registration via find_or_create_by!).
    def connect_organization(event_registration, organization)
      return unless organization

      event_registration.event_registration_organizations
        .find_or_create_by!(organization: organization)
    end

    def create_affiliation(person, organization, organization_address = nil)
      AffiliationServices::CreateFromRegistration.call(
        person: person,
        organization: organization,
        job_title: field_value(ORGANIZATION_POSITION_IDENTIFIER),
        training_date: @event.start_date,
        organization_address: organization_address
      )
    end

    def create_agency_address(organization)
      OrganizationServices::UpsertAddress.call(
        organization: organization,
        street_address: field_value("agency_street"),
        city: field_value("agency_city"),
        state: field_value("agency_state"),
        zip_code: field_value("agency_zip"),
        country: field_value("agency_country")
      )
    end

    def assign_tags(person, organization)
      primary_sector_ids = collect_sector_ids(FormField::PRIMARY_SECTOR_FIELD_IDENTIFIERS)
      additional_sector_ids = collect_sector_ids(FormField::ADDITIONAL_SECTOR_FIELD_IDENTIFIERS)
      primary_age_ids = collect_ids_from_checkboxes("primary_age_group")
      additional_age_ids = collect_ids_from_checkboxes("additional_age_group")

      if primary_sector_ids.any? || additional_sector_ids.any?
        SectorTagging.apply(person: person, organizations: [ organization ],
                            primary_ids: primary_sector_ids, additional_ids: additional_sector_ids)
      end

      if primary_age_ids.any? || additional_age_ids.any?
        person.tag_age_groups(primary_ids: primary_age_ids, additional_ids: additional_age_ids)
        organization&.tag_age_groups(primary_ids: primary_age_ids, additional_ids: additional_age_ids)
      end
    end

    def collect_sector_ids(identifiers)
      identifiers.flat_map { |id| collect_ids_from_checkboxes(id) }
    end

    def collect_ids_from_checkboxes(identifier)
      field = @registration_form.form_fields.find_by(field_identifier: identifier)
      return [] unless field

      value = @form_params[field.id.to_s]
      Array(value).reject(&:blank?).map(&:to_i)
    end

    def create_event_registration(person)
      @event.event_registrations.create!(
        registrant: person,
        scholarship_requested: @scholarship_requested,
        w9_requested: w9_requested?,
        invoice_requested: invoice_requested?,
        expected_payment_method: field_value("payment_method")&.strip.presence
      )
    end

    # Create the registrant's CE registration when they opt in, against a license
    # found-or-created from the license-number answer (a placeholder license when
    # none was given). Hours come from the event via the model. No-op when they
    # didn't opt in or a CE registration already exists for this registration.
    def create_ce_registration(event_registration, person)
      return unless ce_credit_requested?
      return if event_registration.continuing_education_registrations.exists?

      license = ProfessionalLicense.find_or_create_for(person: person, number: ce_license_number, kind: ce_license_kind)
      if ce_license_issuing_state || ce_license_expires_on
        license.update!(issuing_state: ce_license_issuing_state, expires_on: ce_license_expires_on)
      end
      event_registration.continuing_education_registrations.create!(professional_license: license)
    end

    def ce_credit_requested?
      return false unless @continuing_education_form

      ce_field_value(CE_CREDIT_INTEREST_IDENTIFIER).to_s.strip.casecmp?("yes")
    end

    def ce_license_number
      return nil unless @continuing_education_form

      ce_field_value(CE_LICENSE_NUMBER_IDENTIFIER)&.strip.presence
    end

    def ce_license_kind
      return nil unless @continuing_education_form

      ce_field_value(CE_LICENSE_KIND_IDENTIFIER)&.strip.presence
    end

    def ce_license_issuing_state
      return nil unless @continuing_education_form

      ce_field_value(CE_LICENSE_ISSUING_STATE_IDENTIFIER)&.strip.presence
    end

    def ce_license_expires_on
      return nil unless @continuing_education_form

      ce_field_value(CE_LICENSE_EXPIRES_ON_IDENTIFIER).presence
    end

    def ce_field_value(key)
      field = @continuing_education_form.form_fields.find_by(field_identifier: key)
      return nil unless field

      @continuing_education_params[field.id.to_s]
    end

    # The "Additional forms" question is a multi-select, so its submitted value is
    # an array of the checked option labels (e.g. [ "Invoice", "W-9" ]).
    def additional_forms_selections
      Array(field_value(ADDITIONAL_FORMS_IDENTIFIER)).map { |value| value.to_s.strip }
    end

    def w9_requested?
      additional_forms_selections.any? { |value| value.casecmp?(ADDITIONAL_FORMS_W9) }
    end

    def invoice_requested?
      additional_forms_selections.any? { |value| value.casecmp?(ADDITIONAL_FORMS_INVOICE) }
    end

    def create_form_submission(person)
      submission = FormSubmission.create!(person: person, form: @registration_form, event: @event, role: "registration")
      save_form_answers(submission)
      OtherResponses::CaptureFromSubmission.call(submission)
      submission
    end

    def update_form_submission(person)
      submission = FormSubmission.find_or_create_by!(person: person, form: @registration_form, role: "registration", event: @event) do |record|
        record.event = @event
      end
      save_form_answers(submission)
      OtherResponses::CaptureFromSubmission.call(submission)
      submission
    end

    def save_form_answers(submission)
      @form_params.each do |field_id, raw_value|
        field = @registration_form.form_fields.find_by(id: field_id)
        next unless field
        next if field.group_header? || field.field_identifier == "confirm_email"

        text = if raw_value.is_a?(Array)
          raw_value.reject(&:blank?).join(", ")
        else
          raw_value.to_s
        end

        record = submission.form_answers.find_or_initialize_by(form_field: field)
        record.update!(submitted_answer: text, question_name_when_answered: field.name)
      end
    end

    # Persist the answers to the separate scholarship form (when one is asked and a
    # scholarship was requested) as its own role: "scholarship" submission tied to
    # the event, mirroring how the registration submission is saved above.
    def save_scholarship_submission(person)
      return unless @scholarship_requested && @scholarship_form && @scholarship_params.present?

      submission = FormSubmission.find_or_create_by!(
        person: person, form: @scholarship_form, role: "scholarship", event: @event
      ) do |record|
        record.event = @event
      end

      @scholarship_params.each do |field_id, raw_value|
        field = @scholarship_form.form_fields.find_by(id: field_id)
        next unless field
        next if field.group_header?

        text = if raw_value.is_a?(Array)
          raw_value.reject(&:blank?).join(", ")
        else
          raw_value.to_s
        end

        record = submission.form_answers.find_or_initialize_by(form_field: field)
        record.update!(submitted_answer: text, question_name_when_answered: field.name)
      end

      OtherResponses::CaptureFromSubmission.call(submission)
    end

    def save_continuing_education_submission(person)
      return unless @continuing_education_form && @continuing_education_params.present?

      submission = FormSubmission.find_or_create_by!(
        person: person, form: @continuing_education_form, role: "continuing_education", event: @event
      ) do |record|
        record.event = @event
      end

      @continuing_education_params.each do |field_id, raw_value|
        field = @continuing_education_form.form_fields.find_by(id: field_id)
        next unless field
        next if field.group_header?

        text = if raw_value.is_a?(Array)
          raw_value.reject(&:blank?).join(", ")
        else
          raw_value.to_s
        end

        record = submission.form_answers.find_or_initialize_by(form_field: field)
        record.update!(submitted_answer: text, question_name_when_answered: field.name)
      end
    end

    def send_notifications(event_registration)
      registrant_email = event_registration.registrant.preferred_email

      NotificationServices::CreateNotification.call(
        noticeable: event_registration,
        kind: :event_registration_confirmation,
        recipient_role: :person,
        recipient_email: registrant_email,
        notification_type: 0
      )

      NotificationServices::CreateNotification.call(
        noticeable: event_registration,
        kind: :event_registration_confirmation_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0
      )
    end
  end
end
