class FormSubmission < ApplicationRecord
  belongs_to :person
  belongs_to :form
  belongs_to :event, optional: true
  has_many :form_answers, dependent: :destroy
  has_one :payment

  accepts_nested_attributes_for :form_answers

  scope :bulk_payment, -> { where(role: "bulk_payment") }

  validates :slug, uniqueness: true, allow_nil: true

  # Bulk payment submissions are reachable by their payer (who has no account)
  # through a public, slug-based ticket URL. Other roles are reached by id.
  before_create :generate_slug, if: :bulk_payment?

  def self.generate_unique_slug
    loop do
      slug = SecureRandom.urlsafe_base64(16)
      break slug unless exists?(slug: slug)
    end
  end

  def bulk_payment?
    role == "bulk_payment"
  end

  # The event this submission belongs to: the directly stored one, or — for
  # submissions created before event_id existed — resolved through the form's
  # matching join role.
  def resolved_event
    event || form.events.find_by(event_forms: { role: role })
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

  # Number of attendees the payer submitted, falling back to the size of the
  # attendees list when an explicit count is absent.
  def bulk_payment_attendee_count
    count = answers_by_identifier["number_of_attendees"].to_i
    count.positive? ? count : bulk_payment_attendees.size
  end

  # Expected total for the submission (event cost times attendee count), so the
  # amount can be shown even before a payment record lands.
  def bulk_payment_amount_cents(event)
    event.cost_cents.to_i * bulk_payment_attendee_count
  end

  # A bulk payment has no owed-balance/paid-in-full concept, so its receipt simply
  # records whatever was paid — it unlocks as soon as a payment is on file, the
  # same signal the ticket uses to show "Payment received".
  def bulk_payment_receipt_available?
    bulk_payment? && payment.present?
  end

  # --- Linked registrations (bulk payment designations) ---

  def linked_registration_ids
    (metadata || {}).fetch("linked_registration_ids", [])
  end

  def link_registration!(event_registration_id)
    ids = linked_registration_ids | [ event_registration_id.to_i ]
    update!(metadata: (metadata || {}).merge("linked_registration_ids" => ids))
  end

  def unlink_registration!(event_registration_id)
    ids = linked_registration_ids - [ event_registration_id.to_i ]
    update!(metadata: (metadata || {}).merge("linked_registration_ids" => ids))
  end

  def linked_registrations
    EventRegistration.where(id: linked_registration_ids)
  end

  private

  def generate_slug
    self.slug ||= self.class.generate_unique_slug
  end
end
