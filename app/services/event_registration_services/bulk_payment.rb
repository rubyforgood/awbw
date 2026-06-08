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
        submission = create_form_submission(person)
        Result.new(success?: true, form_submission: submission, errors: [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, form_submission: nil, errors: [ e.message ])
    end

    private

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

    def create_form_submission(person)
      submission = FormSubmission.create!(person: person, form: @form, role: "bulk_payment")
      save_form_answers(submission)
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
