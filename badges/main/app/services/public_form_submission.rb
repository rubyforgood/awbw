# Records a submission to a standalone, published form filled out at its public
# pretty URL (see PublicFormsController). Unlike event registration there is no
# event, role, or account — the respondent is find-or-created as a Person from
# the form's name/email answers. Answers persist via FormSubmission#persist_answer.
class PublicFormSubmission
  Result = Struct.new(:success?, :form_submission, :person, :errors, keyword_init: true)

  ROLE = "public".freeze

  # Shown when the form lacks the name/email questions needed to build a Person.
  IDENTITY_MISSING_MESSAGE =
    "This form can't accept submissions yet — it needs a name and email question. Please contact us.".freeze

  def self.call(form:, form_params:)
    new(form:, form_params:).call
  end

  def initialize(form:, form_params:)
    @form = form
    @form_params = form_params || {}
  end

  def call
    ActiveRecord::Base.transaction do
      person = find_or_create_person
      return Result.new(success?: false, errors: [ IDENTITY_MISSING_MESSAGE ]) unless person

      record_mailing_list_consent(person)

      submission = FormSubmission.create!(person: person, form: @form, role: ROLE)
      save_form_answers(submission)
      OtherResponses::CaptureFromSubmission.call(submission)
      send_notifications(submission)

      Result.new(success?: true, form_submission: submission, person: person, errors: [])
    end
  rescue FormSubmission::UnreadableUpload => e
    Result.new(success?: false, errors: [ e.message ])
  rescue ActiveRecord::ValueTooLong
    Result.new(success?: false, errors: [ "One of your answers is too long. Please shorten it and try again." ])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, errors: [ e.message ])
  end

  private

  def field_value(identifier)
    field = @form.form_fields.find_by(field_identifier: identifier)
    return nil unless field

    @form_params[field.id.to_s]
  end

  # Reuses an existing Person on an email + last-name match so a returning
  # respondent isn't duplicated; nil when the form didn't collect name + email.
  def find_or_create_person
    first_name = field_value("first_name")&.strip
    last_name = field_value("last_name")&.strip
    email = field_value("primary_email")&.strip&.downcase
    return nil if email.blank? || first_name.blank? || last_name.blank?

    find_matching_person(last_name: last_name, email: email) || Person.create!(
      first_name: first_name,
      last_name: last_name,
      pronouns: field_value("pronouns")&.strip,
      email: email,
      email_type: field_value("primary_email_type")&.downcase
    )
  end

  def find_matching_person(last_name:, email:)
    Person
      .where("LOWER(email) = ? AND LOWER(last_name) = ?", email.downcase, last_name.downcase)
      .first
  end

  # Opt-in, recorded once — never re-stamped or cleared from here.
  def record_mailing_list_consent(person)
    return if person.mailing_list_consent_at.present?
    return unless Array(field_value("communication_consent")).any? { |value| value.to_s.strip.present? }

    person.update!(
      mailing_list_consent_at: Time.current,
      mailing_list_consent_source: "#{@form.display_name} (public form)"
    )
  end

  def save_form_answers(submission)
    @form_params.each do |field_id, raw_value|
      field = @form.form_fields.find_by(id: field_id)
      next unless field
      next if field.group_header? || field.field_identifier == "confirm_email"

      submission.persist_answer(field, raw_value)
    end
  end

  # A confirmation to the submitter and an FYI to the AWBW team, mirroring the
  # event-registration flow.
  def send_notifications(submission)
    NotificationServices::CreateNotification.call(
      noticeable: submission,
      kind: :form_submission_confirmation,
      recipient_role: :person,
      recipient_email: submission.person.preferred_email,
      notification_type: 0
    )

    NotificationServices::CreateNotification.call(
      noticeable: submission,
      kind: :form_submission_confirmation_fyi,
      recipient_role: :admin,
      recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      notification_type: 0
    )
  end
end
