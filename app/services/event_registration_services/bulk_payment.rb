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
        create_phone_contact(person) if field_value("payer_phone").present?
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
      # Snapshot the expected total (event cost times attendee count) now that the
      # answers it derives from are saved, so the ticket can show the right figure
      # before Stripe reports the actual payment back.
      submission.update!(submitted_amount_cents: submission.bulk_payment_amount_cents(@event))
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
