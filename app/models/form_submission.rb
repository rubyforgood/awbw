class FormSubmission < ApplicationRecord
  belongs_to :person
  belongs_to :form
  has_many :form_answers, dependent: :destroy
  has_many :payments

  accepts_nested_attributes_for :form_answers

  # The event this submission belongs to, resolved through the join role that
  # matches the submission's own role (e.g. a "bulk_payment" submission maps to
  # the event_form with role "bulk_payment").
  def event
    form.events.find_by(event_forms: { role: role })
  end

  # Answers keyed by their field's identifier. Bulk payment (and similar) forms
  # address fields by identifier rather than position.
  def answers_by_identifier
    form_answers.includes(:form_field).each_with_object({}) do |answer, map|
      identifier = answer.form_field&.field_identifier
      map[identifier] = answer.submitted_answer if identifier.present?
    end
  end

  # Attendees captured by the bulk payment form, stored as a JSON array under the
  # "bulk_payment_attendees" field.
  def bulk_payment_attendees
    raw = answers_by_identifier["bulk_payment_attendees"]
    return [] if raw.blank?

    parsed = JSON.parse(raw)
    parsed.is_a?(Array) ? parsed : []
  rescue JSON::ParserError
    []
  end
end
