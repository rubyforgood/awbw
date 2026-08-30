class RegistrationTicketCalloutForm < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # Ordered join between a callout and the forms it delivers inline. Each row
  # carries its own `display_from` drip gate, so one callout can open several
  # forms on their own dates (e.g. a Day 1 and Day 2 evaluation). A callout with
  # a single row behaves like a plain single-form callout.
  belongs_to :registration_ticket_callout
  belongs_to :form

  positioned on: :registration_ticket_callout_id

  validates :form_id, uniqueness: { scope: :registration_ticket_callout_id }
  validates :position, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

  scope :ordered, -> { order(:position, :id) }

  # Drips like a callout: hidden until its own date passes. A blank date is open.
  def dripping?(now = Time.current)
    display_from.present? && display_from > now
  end
end
