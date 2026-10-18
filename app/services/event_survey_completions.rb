# The survey roles an event carries — delivered on any of its callouts or already
# answered for it — and each registrant's first submission of each one.
class EventSurveyCompletions
  Completion = Data.define(:submission_id, :submitted_at)

  def initialize(event, person_ids)
    @event = event
    @person_ids = person_ids
  end

  def roles
    @roles ||= Form::SURVEY_ROLES & (delivered_roles + answered_roles)
  end

  def completion(person_id, role)
    completions[[ person_id, role ]]
  end

  private

  def delivered_roles
    RegistrationTicketCalloutForm.joins(:registration_ticket_callout, :form)
      .where(registration_ticket_callouts: { event_id: @event.id }, forms: { role: Form::SURVEY_ROLES })
      .distinct.pluck("forms.role")
  end

  def answered_roles
    event_survey_submissions.distinct.pluck("forms.role")
  end

  def completions
    @completions ||= event_survey_submissions.where(person_id: @person_ids).order(:created_at)
      .pluck(:id, :person_id, "forms.role", :created_at)
      .each_with_object({}) do |(id, person_id, role, submitted_at), map|
        map[[ person_id, role ]] ||= Completion.new(submission_id: id, submitted_at:)
      end
  end

  def event_survey_submissions
    FormSubmission.joins(:form).where(event_id: @event.id, forms: { role: Form::SURVEY_ROLES })
  end
end
