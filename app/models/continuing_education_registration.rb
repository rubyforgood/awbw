class ContinuingEducationRegistration < ApplicationRecord
  has_paper_trail

  belongs_to :event_registration
  belongs_to :professional_license
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :allocations, as: :allocatable, dependent: :destroy
  has_many :payments, through: :allocations, source: :source, source_type: "Payment"

  # Fulfillment lifecycle. Plain strings (no enum, per project convention):
  #   requested → paid (auto, on full payment) → issued (admin), or not_issued.
  STATUSES = %w[ requested paid issued not_issued ].freeze

  before_validation :default_from_event, on: :create

  validates :status, inclusion: { in: STATUSES }
  validates :hours, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :license_belongs_to_registrant

  # Allocatable payment interface — mirrors EventRegistration so a CE registration
  # behaves the same way wherever allocations are summed. "Covered" counts every
  # allocation (payments, discounts, scholarships); payments_sum is cash only.
  def allocations_sum
    return allocations.to_a.sum(&:amount) if allocations.loaded?
    allocations.sum(:amount)
  end

  def payments_sum
    return allocations.to_a.select { |a| a.source_type == Payment.polymorphic_name }.sum(&:amount) if allocations.loaded?
    allocations.where(source_type: Payment.polymorphic_name).sum(:amount)
  end

  def remaining_cost
    [ cost_cents - allocations_sum, 0 ].max
  end

  # A zero-cost CE registration counts as paid (allocations_sum >= 0). That's
  # intentional and only ever reached for already-existing zero-cost records:
  # Allocation#validate_ce_registration_cost forbids *allocating* to a zero-cost
  # CE in the first place, so the two layers encode "no cost" with opposite
  # intent on purpose — nothing to pay here vs. nothing may be paid there.
  def paid_in_full?
    allocations_sum >= cost_cents.to_i
  end

  # Public-facing payment predicate, mirroring EventRegistration#paid? so a CE
  # registration answers the same message wherever allocatables are treated alike.
  def paid?
    paid_in_full?
  end

  def partially_paid?
    !paid_in_full? && payments_sum.to_i.positive?
  end

  # Advance requested↔paid to track real payments without clobbering a later
  # admin state (issued/not_issued). Called when allocations change.
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
    self.hours = event.ce_hours_offered if event&.ce_hours_offered && (hours.blank? || hours.zero?)
    self.cost_cents = event.ce_hours_cost_cents if event&.ce_hours_cost_cents && (cost_cents.blank? || cost_cents.zero?)
  end

  def license_belongs_to_registrant
    return if professional_license.blank? || event_registration.blank?
    return if professional_license.person_id == event_registration.registrant_id

    errors.add(:professional_license, "must belong to the registrant")
  end
end
