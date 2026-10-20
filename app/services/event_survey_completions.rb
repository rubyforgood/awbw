# The survey roles an event carries — offered to its kind of event and delivered
# on any of its callouts, or already answered for it — and each registrant's first
# submission of each one.
class EventSurveyCompletions
  Completion = Data.define(:submission_id, :submitted_at)

  def initialize(event, person_ids)
    @event = event
    @person_ids = person_ids
  end

  def roles
    @roles ||= begin
      delivered = delivered_roles
      answered = answered_roles
      Form::SURVEY_ROLES.select { |role| (offered?(role) && delivered.include?(role)) || answered.include?(role) }
    end
  end

  def completion(person_id, role)
    completions[[ person_id, role ]]
  end

  private

  def offered?(role)
    case role
    when "day_1_survey" then live_training?
    when "day_2_survey" then live_training? && @event.day_count >= 2
    when "recipient_survey" then @event.cost_cents.to_i.positive?
    else true
    end
  end

  def live_training?
    @event.facilitator_training? && !@event.on_demand?
  end

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
