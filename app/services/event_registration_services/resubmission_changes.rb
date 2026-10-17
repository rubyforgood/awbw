module EventRegistrationServices
  # Plain-language notes on what a resubmission changed on an existing registration.
  # They travel in the duplicate notifications' custom_message, one note per line.
  class ResubmissionChanges
    SCHOLARSHIP_REQUESTED = "Scholarship now requested".freeze

    NEWLY_REQUESTED_NOTES = {
      scholarship_requested: SCHOLARSHIP_REQUESTED,
      ce_requested: "Continuing education credit now requested",
      w9_requested: "W-9 now requested",
      invoice_requested: "Invoice now requested"
    }.freeze

    # Answers already reported through the registration settings above.
    SETTINGS_FIELD_IDENTIFIERS = [
      "payment_method", "confirm_email",
      PublicRegistration::ADDITIONAL_FORMS_IDENTIFIER, PublicRegistration::SOMEONE_ELSE_WILL_PAY_IDENTIFIER
    ].freeze

    attr_reader :notes

    def self.snapshot(registration)
      {
        scholarship_requested: registration.scholarship_requested?,
        ce_requested: registration.continuing_education_registrations.exists?,
        w9_requested: registration.w9_requested?,
        invoice_requested: registration.invoice_requested?,
        expected_payment_method: registration.expected_payment_method.presence,
        someone_else_will_pay: registration.someone_else_will_pay?,
        organization_ids: registration.event_registration_organizations.pluck(:organization_id)
      }
    end

    def self.between(before, after, submission: nil)
      notes = NEWLY_REQUESTED_NOTES.filter_map { |key, note| note if after[key] && !before[key] }
      if before[:expected_payment_method] != after[:expected_payment_method]
        notes << "Payment method changed from #{before[:expected_payment_method] || "none"} to #{after[:expected_payment_method] || "none"}"
      end
      if before[:someone_else_will_pay] != after[:someone_else_will_pay]
        notes << (after[:someone_else_will_pay] ? "Someone else will now pay" : "Someone else is no longer paying")
      end
      linked = Organization.where(id: after[:organization_ids] - before[:organization_ids]).order(:name).pluck(:name)
      notes.concat(linked.map { |name| "Organization linked: #{name}" })
      notes.concat(answer_notes(submission)) if submission
      new(notes)
    end

    # Each answer that differs from the person's previous submission of this form
    # for the event, squished to one line so it fits the newline-separated message.
    # A missing answer is skipped: hidden "answers on file" fields aren't posted.
    def self.answer_notes(submission)
      previous = FormSubmission.where(person_id: submission.person_id, event_id: submission.event_id, role: submission.role)
        .where.not(id: submission.id).order(:created_at, :id).last
      return [] unless previous

      previous_answers = previous.form_answers.index_by(&:form_field_id)
      submission.form_answers.includes(:form_field).order(:id).filter_map do |answer|
        next if answer.form_field.nil? || answer.form_field.field_identifier.in?(SETTINGS_FIELD_IDENTIFIERS)

        now = answer.submitted_answer.to_s.squish
        was = previous_answers[answer.form_field_id]&.submitted_answer.to_s.squish
        next if now.blank? || now == was

        question = (answer.question_name_when_answered.presence || answer.form_field.name).squish.truncate(60)
        next "#{question}: added #{now.truncate(80)}" if was.blank?

        "#{question}: changed from #{was.truncate(80)} to #{now.truncate(80)}"
      end
    end

    def self.from_message(message)
      new(message.to_s.split("\n").map(&:strip).compact_blank)
    end

    def initialize(notes)
      @notes = notes
    end

    def to_message
      @notes.join("\n").presence
    end

    def subject_suffix
      return " (scholarship now requested)" if @notes.include?(SCHOLARSHIP_REQUESTED)

      " (registration changed)" if @notes.any?
    end
  end
end
