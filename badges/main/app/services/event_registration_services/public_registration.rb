module EventRegistrationServices
  class PublicRegistration
    Result = Struct.new(:success?, :event_registration, :form_submission, :errors, keyword_init: true)

    # Well-known field_identifier of the "magic" CE question seeded onto the
    # registration form. Answering it "Yes" toggles the registration's
    # ce_credit_requested flag. Kept here so the seed, service, and specs agree.
    CE_CREDIT_INTEREST_IDENTIFIER = "ce_credit_interest".freeze

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

    def self.call(event:, form:, form_params:, scholarship_requested: false, person: nil,
                  scholarship_form: nil, scholarship_params: {})
      new(event:, form:, form_params:, scholarship_requested:, person:,
          scholarship_form:, scholarship_params:).call
    end

    def initialize(event:, form:, form_params:, scholarship_requested: false, person: nil,
                   scholarship_form: nil, scholarship_params: {})
      @event = event
      @form = form
      @form_params = form_params
      @scholarship_requested = scholarship_requested
      @person = person
      @scholarship_form = scholarship_form
      @scholarship_params = scholarship_params || {}
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        person = find_or_create_person

        create_mailing_address(person) if field_value("mailing_city").present?
        create_phone_contact(person) if field_value("phone").present?

        organization = find_organization if field_value(ORGANIZATION_NAME_IDENTIFIER).present?
        create_affiliation(person, organization) if organization
        create_agency_address(organization) if organization && field_value("agency_city").present?

        assign_tags(person, organization)

        existing = @event.event_registrations.find_by(registrant: person)
        if existing
          existing.update!(scholarship_requested: true) if @scholarship_requested
          existing.update!(ce_credit_requested: true, ce_hours_requested: ce_hours_requested) if ce_credit_requested?
          existing.update!(w9_requested: true) if w9_requested?
          existing.update!(invoice_requested: true) if invoice_requested?
          if existing.status == "cancelled"
            existing.update!(status: "registered")
            send_notifications(existing)
          end
          submission = update_form_submission(person)
          save_scholarship_submission(person)
          return Result.new(success?: true, event_registration: existing, form_submission: submission, errors: [])
        end

        event_registration = create_event_registration(person)
        submission = create_form_submission(person)
        save_scholarship_submission(person)

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
      field = @form.form_fields.find_by(field_identifier: key)
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
        return existing
      end

      person.addresses.where(primary: true).update_all(primary: false, inactive: true)

      person.addresses.create!(
        street_address: field_value("mailing_street"),
        city: new_city,
        state: new_state,
        zip_code: field_value("mailing_zip"),
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

    def create_affiliation(person, organization)
      AffiliationServices::CreateFromRegistration.call(
        person: person,
        organization: organization,
        job_title: field_value(ORGANIZATION_POSITION_IDENTIFIER),
        training_date: @event.start_date
      )
    end

    def create_agency_address(organization)
      new_city = field_value("agency_city")&.strip
      new_state = field_value("agency_state")&.strip

      existing = organization.addresses.find_by(
        "LOWER(city) = ? AND LOWER(COALESCE(state, '')) = ?",
        new_city&.downcase, new_state&.downcase.to_s
      )

      if existing
        existing.update!(
          street_address: field_value("agency_street"),
          zip_code: field_value("agency_zip"),
          primary: true,
          inactive: false
        )
        return existing
      end

      organization.addresses.where(primary: true).update_all(primary: false, inactive: true)

      organization.addresses.create!(
        street_address: field_value("agency_street"),
        city: new_city,
        state: new_state,
        zip_code: field_value("agency_zip"),
        locality: "Unknown",
        address_type: "work",
        primary: true
      )
    end

    def assign_tags(person, organization)
      sector_ids = collect_ids_from_checkboxes("primary_service_area_single") +
                   collect_ids_from_checkboxes("primary_service_area")
      primary_age_ids = collect_ids_from_checkboxes("primary_age_group")
      additional_age_ids = collect_ids_from_checkboxes("additional_age_group")

      if sector_ids.any?
        sectors = Sector.where(id: sector_ids)
        assign_primary_sectors(person, sectors)
        organization.sectors = (organization.sectors + sectors).uniq if organization
      end

      if primary_age_ids.any? || additional_age_ids.any?
        person.tag_age_groups(primary_ids: primary_age_ids, additional_ids: additional_age_ids)
        organization&.tag_age_groups(primary_ids: primary_age_ids, additional_ids: additional_age_ids)
      end
    end

    def assign_primary_sectors(person, sectors)
      sectors.each do |sector|
        item = person.sectorable_items.find_or_initialize_by(sector: sector)
        item.update!(is_primary: true)
      end
    end

    def collect_ids_from_checkboxes(identifier)
      field = @form.form_fields.find_by(field_identifier: identifier)
      return [] unless field

      value = @form_params[field.id.to_s]
      Array(value).reject(&:blank?).map(&:to_i)
    end

    def create_event_registration(person)
      @event.event_registrations.create!(
        registrant: person,
        scholarship_requested: @scholarship_requested,
        ce_credit_requested: ce_credit_requested?,
        ce_hours_requested: ce_hours_requested,
        w9_requested: w9_requested?,
        invoice_requested: invoice_requested?
      )
    end

    # The CE-interest answer, which "Yes" folds an hours specify box into as
    # "Yes: <hours>". Split off the leading label so a Yes/No check ignores the
    # folded hours (see FormField::FIELD_SPECIFY_OPTION_PLACEHOLDERS).
    def ce_answer_label
      field_value(CE_CREDIT_INTEREST_IDENTIFIER).to_s.split(":", 2).first.to_s.strip
    end

    # True when the registrant answered "Yes" to the seeded CE-interest question.
    def ce_credit_requested?
      ce_answer_label.casecmp?("yes")
    end

    # The CE hours typed into the "Yes" specify box, as a positive integer, or nil
    # when CE was not requested or no valid hours were entered.
    def ce_hours_requested
      return unless ce_credit_requested?

      hours = field_value(CE_CREDIT_INTEREST_IDENTIFIER).to_s.split(":", 2).last.to_s.strip.to_i
      hours.positive? ? hours : nil
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
      submission = FormSubmission.create!(person: person, form: @form, event: @event)
      save_form_answers(submission)
      submission
    end

    def update_form_submission(person)
      submission = FormSubmission.find_or_create_by!(person: person, form: @form) do |record|
        record.event = @event
      end
      save_form_answers(submission)
      submission
    end

    def save_form_answers(submission)
      @form_params.each do |field_id, raw_value|
        field = @form.form_fields.find_by(id: field_id)
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
        person: person, form: @scholarship_form, role: "scholarship"
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
