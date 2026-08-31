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

  # When this form opens: the later of the callout's own drip date and this row's.
  # The callout's date withholds all of its page content, so a row can't open ahead
  # of the page carrying it. Nil when neither is set.
  def available_from
    [ registration_ticket_callout&.display_from, display_from ].compact.max
  end

  # Drips like a callout: hidden until it opens. No date either side is open.
  def dripping?(now = Time.current)
    available_from.present? && available_from > now
  end
end
