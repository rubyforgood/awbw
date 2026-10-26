# A registrant's form responses for one event, grouped into sittings (FormSubmissionSittings).
# Each sitting carries the registration, scholarship, CE, and bulk payment answers sent in it,
# so the form responses page can show every application as it was submitted.
class RegistrationResponses
  Answers = Data.define(:submission, :responses)

  Sitting = Data.define(:submissions, :registration, :scholarship, :continuing_education, :bulk_payment) do
    def created_at = submissions.first.created_at

    def includes_submission?(id) = submissions.any? { |submission| submission.id.to_s == id.to_s }

    def form_names = submissions.map { |submission| submission.form.name }.join(" + ")
  end

  def initialize(event:, person:)
    @event = event
    @person = person
  end

  # Newest first.
  def sittings
    @sittings ||= grouping.groups.map { |group| build(group) }.sort_by(&:created_at).reverse
  end

  private

  def grouping
    @grouping ||= begin
      roles_by_form_id = @event.event_forms.pluck(:form_id, :role).to_h
      submissions = FormSubmission.where(event: @event, person: @person, form_id: roles_by_form_id.keys)
        .includes(:form, :person, :form_answers).to_a
      FormSubmissionSittings.new(submissions, roles_by_form_id:)
    end
  end

  def build(group)
    by_role = group.group_by { |submission| grouping.role_of(submission) }.transform_values(&:first)
    Sitting.new(
      submissions: group,
      registration: by_role["registration"],
      scholarship: scholarship_answers(group),
      continuing_education: answers_on(by_role["continuing_education"]),
      bulk_payment: by_role["bulk_payment"]
    )
  end

  def answers_on(submission)
    Answers.new(submission:, responses: submission.form_answers.index_by(&:form_field_id)) if submission
  end

  def scholarship_answers(group)
    return unless @event.scholarship_form

    application = ScholarshipApplication.new(event: @event, person: @person, submissions: group)
    Answers.new(submission: application.submission, responses: application.answers_by_field_id) if application.answered?
  end
end
