# The CE-specific view over the inline form the CE callout carries (the generic
# callout→form mechanism lives in #2384: RegistrationTicketCallout#form +
# EventRegistrationServices::CalloutFormSubmission). This adds the two things CE
# needs on top: the post-training form only surfaces once the registrant's
# sign-outs are complete, and completing it is a prerequisite for the CE
# certificate. Built once per registration and read by the CE callout page, the
# CE card nudge, and the certificate gate.
class RegistrantCeForm
  def initialize(event_registration)
    @event_registration = event_registration
  end

  # The form attached to the CE callout, or nil when none is set. The CE callout
  # carries a single form, so this reads the first linked form.
  def form
    ce_callout&.forms&.first
  end

  # Something to fill: a form with at least one non-header field.
  def present?
    answerable_fields.any?
  end

  # Show the step only once the training's sign-outs are done.
  def available?
    @event_registration.ce_signouts_complete?
  end

  # This registrant's submission for the CE callout's form, if one exists. Keyed
  # the same way CalloutFormSubmission stores and Callouts#callout_submission reads
  # it, so the two never drift.
  def submission
    return unless form

    form.form_submissions.find_by(person: @event_registration.registrant,
                                  event: @event_registration.event,
                                  role: form.role)
  end

  # Every required field answered — the read-time "form complete" signal, since
  # FormSubmission has no completed_at column.
  def complete?
    return false unless submission

    answerable_fields.select(&:required).all? { |field| answers_by_field_id[field.id].present? }
  end

  private

  def answerable_fields
    return [] unless form

    form.form_fields.reject(&:group_header?)
  end

  def answers_by_field_id
    @answers_by_field_id ||= submission.form_answers
      .index_by(&:form_field_id)
      .transform_values(&:submitted_answer)
  end

  def ce_callout
    return @ce_callout if defined?(@ce_callout)

    @ce_callout = @event_registration.event.registration_ticket_callouts.find_by(builtin_key: "ce_hours")
  end
end
