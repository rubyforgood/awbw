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
  ALREADY_SUBMITTED_MESSAGE = "This form was already submitted.".freeze

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

      submission = FormSubmission.create!(person: person, form: @form, role: ROLE)
      # Answers first: the agreement linking core reads the submitted org off
      # them, and a rejected answer (too long, unreadable upload) then aborts
      # before any of the person's own records have been written.
      save_form_answers(submission)

      if person
        record_news_subscription(person)
        registration = register_for_on_demand_training(submission)
        capture_organization(submission, registration)
        PersonServices::CaptureFromSubmission.call(person: person, form: @form, form_params: @form_params)
      end

      OtherResponses::CaptureFromSubmission.call(submission)
      Quotes::CaptureFromSubmission.call(submission)
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
  rescue ActiveRecord::RecordNotUnique => e
    raise unless e.message.include?(Person::NAME_AND_EMAIL_INDEX)

    Result.new(success?: false, errors: [ ALREADY_SUBMITTED_MESSAGE ])
  end

  private

  # A standalone registration-role form is the on-demand agreement (ADR-0002),
  # and submitting it IS registering for the current on-demand facilitator
  # training — so mint that event registration (idempotent via the unique
  # registrant+event index) and stamp the event on the submission. Returns the
  # registration; nil when no current on-demand training exists.
  def register_for_on_demand_training(submission)
    return unless @form.role == "registration"

    event = Event.current_on_demand_facilitator_training
    return unless event

    submission.update!(event: event)
    registration = EventRegistration.find_or_create_by!(event: event, registrant: submission.person)
    # Created "registered" (the column default), then flipped: an on-demand
    # agreement only arrives after the external LMS training is complete.
    registration.update!(status: "attended") unless registration.status == "attended"
    registration
  end

  # A close-program submission end-dates the person's affiliations at the named
  # organization (see AffiliationServices::CloseProgram). We only auto-process
  # when the submitted organization name matches an org exactly (case-insensitive).
  # An unmatched name is left for an admin to resolve on the submission's processing
  # panel, which runs the same service once they link the organization by hand.
  def process_close_program(submission)
    return unless @form.role == "close_program"
    return unless submission.person

    answers = submission.answers_by_identifier
    organization = organization_named(answers[FormField::ORGANIZATION_NAME_FIELD_IDENTIFIER])
    return unless organization

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

  # Link + fill the submitted organization. An agreement submission is processed
  # through the same linking core an admin would run (process_agreement_organization);
  # any other role runs the same capture an event registration does, so a job
  # affiliation comes from the typed position either way. Skipped on a
  # close-program form, whose submission ends affiliations at the org rather than
  # creating them (process_close_program).
  def capture_organization(submission, registration)
    return if @form.role == "close_program"
    return process_agreement_organization(submission, registration) if submission.agreement_scenario?

    organization = OrganizationServices::CaptureFromSubmission.call(
      form: @form, form_params: @form_params, person: submission.person, submission: submission
    ).organization
    submission.link_organization!(organization.id) if organization
    organization
  end

  # An agreement submission whose organization name resolves unambiguously is
  # processed on arrival, the way a close-program submission already is: the
  # linking core applies the scenario (a new job ends the person's other orgs'
  # rows and start-dates the new one), confers the standing Facilitator
  # affiliation, and fills the org's blank profile fields — identical to an admin
  # linking it by hand, so the two paths can't drift (ADR-0002). Anything the
  # core would have to guess at is left for an admin on the submission's linking
  # page.
  def process_agreement_organization(submission, registration)
    organization = organization_named(field_value(FormField::ORGANIZATION_NAME_FIELD_IDENTIFIER))
    return unless organization

    result = OrganizationServices::LinkSubmittedOrganization.call(
      person: submission.person,
      organization: organization,
      entry: submission.org_entry,
      scenario: submission.linking_scenario,
      training_date: submission.created_at.to_date,
      event_registration: registration
    )

    submission.link_organization!(organization.id)
    submission.record_scenario_ended!(result.ended_affiliations.map(&:id))
    link_registration_organization(registration, organization, submission, result.saved)
    organization
  end

  # The same link row, pin, and autofill note the event registration flow
  # records, so the on-demand roster shows the org as linked.
  def link_registration_organization(registration, organization, submission, autofill)
    return unless registration

    link = registration.event_registration_organizations.find_or_create_by!(organization: organization)
    link.record_form_submission(submission)
    link.record_autofill(autofill)
  end

  def organization_named(name)
    Organization.find_by(name: name) if name.present?
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

    # The rest of the profile (pronouns, secondary email, and so on) is filled by
    # CaptureFromSubmission, which runs for both new and existing people.
    find_matching_person(last_name: last_name, email: email) || Person.create!(
      first_name: first_name,
      last_name: last_name,
      email: email,
      email_type: field_value("primary_email_type")&.downcase
    )
  end

  def find_matching_person(last_name:, email:)
    PersonMatcher.call(email:, last_name:)
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
        person: submission.person,
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
      recipient_email: Organization.programs_email,
      notification_type: 0
    )
  end
end
