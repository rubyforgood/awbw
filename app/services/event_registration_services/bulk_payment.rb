module EventRegistrationServices
  class BulkPayment
    Result = Struct.new(:success?, :form_submission, :errors, keyword_init: true)

    def self.call(event:, form:, form_params:, person: nil)
      new(event:, form:, form_params:, person:).call
    end

    def initialize(event:, form:, form_params:, person: nil)
      @event = event
      @form = form
      @form_params = form_params
      @person = person
      @errors = []
    end

    def call
      ActiveRecord::Base.transaction do
        person = find_or_create_person
        # Backfill after the phone-contact guard: create_phone_contact should only
        # fire for a phone the payer actually typed, not one we copied from their
        # own profile (which would needlessly rewrite their contact methods).
        create_phone_contact(person) if field_value("payer_phone").present?
        backfill_payer_fields(person)
        submission = create_form_submission(person)
        send_notifications(submission, person)
        Result.new(success?: true, form_submission: submission, errors: [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, form_submission: nil, errors: [ e.message ])
    end

    private

    # Emails the payer a confirmation and notifies staff with an FYI.
    def send_notifications(submission, person)
      payer_email = person.preferred_email.presence || field_value("payer_email")&.strip
      if payer_email.present?
        NotificationServices::CreateNotification.call(
          noticeable: submission,
          kind: :bulk_payment_confirmation,
          recipient_role: :person,
          recipient_email: payer_email,
          notification_type: 0
        )
      end

      NotificationServices::CreateNotification.call(
        noticeable: submission,
        kind: :bulk_payment_confirmation_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0
      )
    end

    # Logged-in payers don't see the logged_out_only payer fields, so those keys
    # never reach @form_params and the payer's identity would be missing from the
    # saved form answers. Backfill them from the known person, without clobbering
    # anything that was actually submitted.
    def backfill_payer_fields(person)
      {
        "payer_first_name" => person.first_name,
        "payer_last_name" => person.last_name,
        "payer_email" => person.preferred_email,
        "payer_phone" => person.phone_number,
        "payer_organization" => payer_organization_name(person)
      }.each do |key, value|
        next if value.blank?

        field = @form.form_fields.find_by(field_identifier: key)
        next unless field
        next if @form_params[field.id.to_s].present?

        @form_params[field.id.to_s] = value
      end
    end

    # Prefer the org the payer facilitates for, falling back to their most recent
    # active affiliation when they have no facilitator affiliation.
    def payer_organization_name(person)
      (person.program_organization || person.primary_organization)&.name
    end

    def field_value(key)
      field = @form.form_fields.find_by(field_identifier: key)
      return nil unless field
      @form_params[field.id.to_s]
    end

    def find_or_create_person
      return @person if @person

      first_name = field_value("payer_first_name")&.strip
      last_name = field_value("payer_last_name")&.strip
      email = field_value("payer_email")&.strip&.downcase

      person = Person.find_by(
        "LOWER(first_name) = ? AND LOWER(last_name) = ? AND LOWER(email) = ?",
        first_name&.downcase, last_name&.downcase, email&.downcase
      )
      return person if person

      Person.create!(
        first_name: first_name,
        last_name: last_name,
        email: email
      )
    end

    # Mirrors PublicRegistration#create_phone_contact. The bulk payment form has
    # no phone-type field, so the payer phone is always stored as personal.
    def create_phone_contact(person)
      phone_value = field_value("payer_phone")&.strip
      return if phone_value.blank?

      existing = person.contact_methods.find_by(kind: :phone, value: phone_value)
      if existing
        existing.update!(contact_type: "personal", primary: true, inactive: false)
        return existing
      end

      person.contact_methods.where(kind: :phone, primary: true).update_all(primary: false, inactive: true)

      person.contact_methods.create!(
        kind: :phone,
        value: phone_value,
        contact_type: "personal",
        primary: true
      )
    end

    def create_form_submission(person)
      submission = FormSubmission.create!(person: person, form: @form, event: @event, role: "bulk_payment")
      save_form_answers(submission)
      OtherResponses::CaptureFromSubmission.call(submission)
      submission
    end

    def save_form_answers(submission)
      @form_params.each do |field_id, raw_value|
        field = @form.form_fields.find_by(id: field_id)
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
  end
end
