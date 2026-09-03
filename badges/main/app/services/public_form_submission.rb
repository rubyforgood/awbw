# Records a submission to a standalone, published form filled out at its public
# pretty URL (see PublicFormsController). Unlike event registration there is no
# event, role, or account — the respondent is find-or-created as a Person from
# the form's name/email answers. When those questions are optional and left
# blank the submission stands anonymously (person: nil); a required-but-blank
# identity question is already blocked upstream by the form's field validation.
# Answers persist via FormSubmission#persist_answer.
class PublicFormSubmission
  Result = Struct.new(:success?, :form_submission, :person, :errors, keyword_init: true)

  ROLE = "public".freeze

  # An agreement form (registration / new job / reinstatement) can't do its job
  # — process the submission against a Person — without one, so it's rejected
  # rather than recorded anonymously.
  IDENTITY_REQUIRED_MESSAGE =
    "This form needs your name and email to complete your submission.".freeze

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
      return Result.new(success?: false, errors: [ IDENTITY_REQUIRED_MESSAGE ]) if @form.requires_identity? && person.nil?

      record_news_subscription(person) if person

      submission = FormSubmission.create!(person: person, form: @form, role: ROLE)
      save_form_answers(submission)
      OtherResponses::CaptureFromSubmission.call(submission)
      Quotes::CaptureFromSubmission.call(submission)
      register_for_on_demand_training(submission)
      process_close_program(submission)
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

  # A standalone registration-role form is the on-demand agreement (ADR-0002),
  # and submitting it IS registering for the current on-demand facilitator
  # training — so mint that event registration (idempotent via the unique
  # registrant+event index) and stamp the event on the submission. A quiet
  # no-op when no current on-demand training exists.
  def register_for_on_demand_training(submission)
    return unless @form.role == "registration"
    # Registration mints a facilitator event registration — impossible without an
    # identified person, so an anonymous submission skips it.
    return unless submission.person

    event = Event.current_on_demand_facilitator_training
    return unless event

    submission.update!(event: event)
    registration = EventRegistration.find_or_create_by!(event: event, registrant: submission.person)
    # Created "registered" (the column default), then flipped: an on-demand
    # agreement only arrives after the external LMS training is complete.
    registration.update!(status: "attended") unless registration.status == "attended"
  end

  # A close-program submission end-dates the person's affiliations at the named
  # organization (see AffiliationServices::CloseProgram). We only auto-process
  # when the submitted organization name resolves to exactly one org — an exact,
  # case-insensitive name match. Anything ambiguous (no match, or two same-named
  # orgs) is left for an admin to resolve on the submission's processing panel,
  # which runs the same service once they link the organization by hand.
  def process_close_program(submission)
    return unless @form.role == "close_program"
    return unless submission.person

    answers = submission.answers_by_identifier
    name = answers["organization_name"].to_s.strip
    return if name.blank?

    matches = Organization.where("LOWER(name) = ?", name.downcase)
    return unless matches.count == 1

    organization = matches.first
    ended = AffiliationServices::CloseProgram.call(
      person: submission.person,
      organization: organization,
      effective_date: parse_date(answers["close_effective_date"]),
      reason: answers["close_reason"],
      leaving_job: answers["close_leaving_job"].to_s.casecmp?("Yes")
    )

    submission.link_organization!(organization.id)
    submission.record_scenario_ended!(ended.map(&:id))
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

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

  # An affirmative communication-consent answer subscribes the person to the
  # News (mailing-list) topic, recording the form as its source.
  def record_news_subscription(person)
    return unless Array(field_value("communication_consent")).any? { |value| value.to_s.strip.present? }

    NewsSubscriptionCapture.call(person: person, source: "#{@form.display_name} (public form)")
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
    # An anonymous submission has no submitter to confirm to; only the team FYI goes out.
    if submission.person
      NotificationServices::CreateNotification.call(
        noticeable: submission,
        kind: :form_submission_confirmation,
        recipient_role: :person,
        recipient_email: submission.person.preferred_email,
        notification_type: 0
      )
    end

    NotificationServices::CreateNotification.call(
      noticeable: submission,
      kind: :form_submission_confirmation_fyi,
      recipient_role: :admin,
      recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      notification_type: 0
    )
  end
end
