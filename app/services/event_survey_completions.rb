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

  # The default survey forms (.survey, i.e. the oldest of each role — what the
  # built-in callouts deliver) that can be handed out as a public link for this
  # event, in role order. Reads every role's form in one pass and asks one
  # instance about all of them, so the callout lookup runs once however many
  # survey forms are published: this renders on the event dashboard and the
  # registrants roster. The publicly-fillable test is the query form of
  # Form#publicly_fillable?.
  def self.survey_forms_for(event)
    return [] unless event

    forms = Form.standalone.published.not_event_connected
      .where(id: Form.survey_default_ids).where.not(slug: [ nil, "" ]).index_by(&:role)
    completions = new(event, [])
    Form::SURVEY_ROLES.filter_map { |role| forms[role] if completions.survey_allowed?(forms[role]) }
  end

  def initialize(event, person_ids)
    @event = event
    @person_ids = person_ids
  end

  def roles
    @roles ||= Form::SURVEY_ROLES.select do |role|
      (offered?(role) && delivered_roles.include?(role)) || answered_roles.include?(role)
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

  # Memoized: both are asked once per survey role — by #roles, and by the
  # #survey_allowed? .survey_forms_for asks for each role's form.
  def delivered_roles
    @delivered_roles ||= RegistrationTicketCalloutForm.joins(:registration_ticket_callout, :form)
      .where(registration_ticket_callouts: { event_id: @event.id }, forms: { role: Form::SURVEY_ROLES })
      .distinct.pluck("forms.role")
  end

  def answered_roles
    @answered_roles ||=
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
