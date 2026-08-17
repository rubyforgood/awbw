# Records a submission to a standalone, published form filled out at its public
# pretty URL (see PublicFormsController). Unlike event registration, there is no
# event, role, or account: the respondent is identified purely from the name and
# email answers on the form, find-or-created as a Person, and their answers are
# stored as a role: "public" FormSubmission.
#
# The answer persistence (including the hardened file-upload path) is shared with
# event registration via FormAnswerPersistence.
class PublicFormSubmission
  include FormAnswerPersistence

  Result = Struct.new(:success?, :form_submission, :person, :errors, keyword_init: true)

  # The role stored on submissions captured through the public standalone-form
  # endpoint, distinguishing them from registration/scholarship/etc. submissions.
  ROLE = "public".freeze

  # Field identifiers the form must carry to identify the respondent. A Person
  # requires a first and last name, so a public form without these can't record a
  # submission — the respondent gets a friendly error rather than a 500.
  IDENTITY_MISSING_MESSAGE =
    "This form can't accept submissions yet — it needs a name and email question. Please contact us.".freeze

  def self.call(form:, form_params:)
    new(form:, form_params:).call
  end

  def initialize(form:, form_params:)
    @form = form
    @form_params = form_params || {}
    @errors = []
  end

  def call
    ActiveRecord::Base.transaction do
      person = find_or_create_person
      return Result.new(success?: false, errors: [ IDENTITY_MISSING_MESSAGE ]) unless person

      record_mailing_list_consent(person)

      submission = FormSubmission.create!(person: person, form: @form, role: ROLE)
      save_form_answers(submission)

      Result.new(success?: true, form_submission: submission, person: person, errors: [])
    end
  rescue FormAnswerPersistence::UnreadableUpload => e
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

  # Identify the respondent from the form's name/email answers. Reuses an existing
  # Person on an email + last-name match (both stable identifiers) so a returning
  # respondent isn't duplicated; creates one otherwise. Returns nil when there's
  # no email or no name to build a Person from — a first/last name are required.
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

  # Consent is opt-in and recorded once. An affirmative answer stamps the time and
  # the source when none is on file; a respondent who already consented is left
  # untouched, and consent is never cleared from here.
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

      persist_answer(submission, field, raw_value)
    end
  end
end
