class ContinuingEducationRegistration < ApplicationRecord
  has_paper_trail

  belongs_to :event_registration
  belongs_to :professional_license
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :allocations, as: :allocatable, dependent: :destroy
  has_many :payments, through: :allocations, source: :source, source_type: "Payment"

  # Fulfillment lifecycle. Plain strings (no enum, per project convention):
  #   requested → paid (auto, on full payment) → issued (admin), or unawarded.
  STATUSES = %w[ requested paid issued unawarded ].freeze

  before_validation :default_from_event, on: :create

  validates :status, inclusion: { in: STATUSES }
  validates :hours, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :license_belongs_to_registrant

  def amount_owed_cents
    [ cost_cents - paid_cents, 0 ].max
  end

  def paid_cents
    if allocations.loaded?
      return allocations.select { |a| a.source_type == "Payment" }.sum(&:amount)
    end
    allocations.where(source_type: "Payment").sum(:amount)
  end

  def paid_in_full?
    paid_cents >= cost_cents
  end

  # Advance requested↔paid to track real payments without clobbering a later
  # admin state (issued/unawarded). Called when allocations change.
  def sync_payment_status!
    return unless status == "requested" || status == "paid"

    target = paid_in_full? ? "paid" : "requested"
    update!(status: target) unless status == target
  end

  private

  # Snapshot the hours offered and total cost from the event when they aren't set
  # explicitly. Both are plain stored values — no per-hour rate is multiplied out.
  def default_from_event
    event = event_registration&.event
    self.hours = event.ce_hours_available if event&.ce_hours_available && (hours.blank? || hours.zero?)
    self.cost_cents = event.ce_hours_cost_cents if event&.ce_hours_cost_cents && (cost_cents.blank? || cost_cents.zero?)
  end

  def license_belongs_to_registrant
    return if professional_license.blank? || event_registration.blank?
    return if professional_license.person_id == event_registration.registrant_id

    errors.add(:professional_license, "must belong to the registrant")
  end
end
