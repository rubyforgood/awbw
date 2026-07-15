class RegistrationTicketCalloutResource < ApplicationRecord
  # Ordered join between a callout and the resources it links to (e.g. the
  # Handouts card's worksheets, or a custom callout's supporting documents).
  # Reordered like the callouts themselves via the positioning gem.
  #
  # `subtitle` is the short line shown on the callout card for this resource;
  # `page_content` is the longer copy shown under the title on the resource's own
  # detail page. Both are editable per event (materialized from
  # BuiltinCallouts for the built-in handouts).
  belongs_to :registration_ticket_callout
  belongs_to :resource

  positioned on: :registration_ticket_callout_id

  validates :resource_id, uniqueness: { scope: :registration_ticket_callout_id }
  validates :position, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

  scope :ordered, -> { order(:position, :id) }
end
