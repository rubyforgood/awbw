# Gathers one person's scholarship-application answers for an event, regardless of
# which submission they were captured on.
#
# The scholarship questions can be asked on a dedicated scholarship form (its own
# role: "scholarship" submission), as a "scholarship" section embedded in the
# registration form, or — for a registrant who answered them while registering —
# stored against the registration submission. A by-submission lookup misses some
# of those shapes, so this gathers a person's answers across every submission they
# made for the event's forms and keeps the ones that belong to a scholarship
# question, the same spirit as EventDashboard's recipients gathering.
class ScholarshipApplication
  # Canonical scholarship question identifiers, used as a backstop so answers
  # recorded against another form's copy of a standard question are still found.
  IDENTIFIERS = FormBuilderService::SECTION_FIELD_IDENTIFIERS[:scholarship].freeze

  def initialize(event:, person:)
    @event = event
    @person = person
  end

  # The scholarship questions in display order: every field on a dedicated
  # scholarship form, plus any "scholarship" section / scholarship-only fields on
  # the registration form.
  def fields
    @fields ||= question_fields.sort_by { |field| field.position.to_i }
  end

  # Visible questions paired with the person's answer (nil when unanswered),
  # dropping group headers and no-input fields. Suitable for a definition list.
  def answer_pairs
    fields
      .reject { |field| field.group_header? || field.no_user_input? }
      .map { |field| [ field, answer_for(field) ] }
  end

  # Answers keyed by their form field id, for views that look up by field.id.
  def answers_by_field_id
    @answers_by_field_id ||= answers.index_by(&:form_field_id)
  end

  def answered?
    answers.any? { |answer| answer.submitted_answer.present? }
  end

  # A submission carrying these answers, for the "submitted on" line and to gate
  # the "view full submission" link: the dedicated scholarship submission when
  # present, otherwise whichever event submission holds the answers (the
  # registration submission for embedded / while-registering answers).
  def submission
    @submission ||= answer_submissions.find { |sub| sub.role == "scholarship" } ||
      answer_submissions.first ||
      submissions.first
  end

  private

  def answer_for(field)
    answers_by_field_id[field.id] || answers_by_identifier[field.field_identifier]
  end

  def answers_by_identifier
    @answers_by_identifier ||= answers
      .reject { |answer| answer.form_field.field_identifier.blank? }
      .index_by { |answer| answer.form_field.field_identifier }
  end

  def question_fields
    fields = []
    fields.concat(@event.scholarship_form.form_fields.to_a) if @event.scholarship_form
    if (registration_form = @event.registration_form)
      fields.concat(registration_form.form_fields.select { |field| field.section == "scholarship" || field.scholarship_only? })
    end
    fields
  end

  def question_field_ids
    @question_field_ids ||= question_fields.map(&:id).to_set
  end

  def question_field_identifiers
    @question_field_identifiers ||= (question_fields.map(&:field_identifier).compact + IDENTIFIERS).to_set
  end

  # The person's non-blank answers — across every submission they made for the
  # event's forms — that belong to a scholarship question, matched by the field
  # itself or, to bridge an answer captured on another form's copy of the same
  # question, by its identifier. Deduplicated to one answer per question.
  def answers
    @answers ||= FormAnswer
      .where(form_submission: submissions)
      .where.not(submitted_answer: [ nil, "" ])
      .includes(:form_field, :form_submission)
      .select { |answer| scholarship_answer?(answer.form_field) }
      .group_by { |answer| answer.form_field.field_identifier.presence || "field-#{answer.form_field_id}" }
      .values
      .map(&:first)
  end

  def scholarship_answer?(field)
    question_field_ids.include?(field&.id) ||
      (field&.field_identifier.present? && question_field_identifiers.include?(field.field_identifier))
  end

  def submissions
    @submissions ||= FormSubmission.where(person: @person, form_id: @event.forms.ids).to_a
  end

  def answer_submissions
    answers.map(&:form_submission).uniq
  end
end
