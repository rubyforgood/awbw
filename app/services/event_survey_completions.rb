# The survey roles an event carries — offered to its kind of event and delivered
# on any of its callouts, or already answered for it — and each registrant's first
# submission of each one. An anonymous survey counts from the registrant's
# FormCompletion, which carries a date and no submission.
class EventSurveyCompletions
  Completion = Data.define(:submission_id, :submitted_at)

  def self.survey_allowed_for_event?(event, form)
    return false unless event && form&.survey_role?

    new(event, []).survey_allowed?(form)
  end

  def self.survey_forms_for(event)
    return [] unless event

    Form::SURVEY_ROLES.filter_map do |role|
      form = Form.survey(role)
      form if form&.publicly_fillable? && survey_allowed_for_event?(event, form)
    end
  end

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

  def survey_allowed?(form)
    return false unless form&.survey_role?

    offered?(form.role) || delivered_roles.include?(form.role)
  end

  private

  def offered?(role)
    case role
    when "day_1_survey" then live_training?
    when "day_2_survey" then live_training? && @event.multi_day?
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
    (event_survey_submissions.distinct.pluck("forms.role") + event_survey_form_completions.distinct.pluck("forms.role")).uniq
  end

  def completions
    @completions ||= begin
      map = event_survey_submissions.where(person_id: @person_ids).order(:created_at)
        .pluck(:id, :person_id, "forms.role", :created_at)
        .each_with_object({}) do |(id, person_id, role, submitted_at), result|
          result[[ person_id, role ]] ||= Completion.new(submission_id: id, submitted_at:)
        end
      event_survey_form_completions.where(person_id: @person_ids).pluck(:person_id, "forms.role", :completed_on)
        .each do |person_id, role, completed_on|
          map[[ person_id, role ]] ||= Completion.new(submission_id: nil, submitted_at: completed_on.in_time_zone)
        end
      map
    end
  end

  def event_survey_submissions
    FormSubmission.joins(:form).where(event_id: @event.id, forms: { role: Form::SURVEY_ROLES })
  end

  def event_survey_form_completions
    FormCompletion.joins(:form).where(event_id: @event.id, forms: { role: Form::SURVEY_ROLES })
  end
end
