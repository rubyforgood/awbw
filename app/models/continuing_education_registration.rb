class ContinuingEducationRegistration < ApplicationRecord
  has_paper_trail

  belongs_to :event_registration
  belongs_to :professional_license
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :allocations, as: :allocatable, dependent: :destroy
  has_many :payments, through: :allocations, source: :source, source_type: "Payment"

  # Default amount a registrant owes per CE hour. The training's ce_hours is
  # multiplied by this to bill the registration.
  HOURLY_RATE_DOLLARS = 25

  # Fulfillment lifecycle. Plain strings (no enum, per project convention):
  #   requested → paid (auto, on full payment) → issued (admin), or unawarded.
  STATUSES = %w[ requested paid issued unawarded ].freeze

  before_validation :default_hours_from_event, on: :create
  before_save :calculate_amount

  validates :status, inclusion: { in: STATUSES }
  validates :hours, numericality: { greater_than_or_equal_to: 0 }
  validate :license_belongs_to_registrant

  def amount_owed_cents
    [ amount_cents - paid_cents, 0 ].max
  end

  def paid_cents
    if allocations.loaded?
      return allocations.select { |a| a.source_type == "Payment" }.sum(&:amount)
    end
    allocations.where(source_type: "Payment").sum(:amount)
  end

  def paid_in_full?
    paid_cents >= amount_cents
  end

  # Advance requested↔paid to track real payments without clobbering a later
  # admin state (issued/unawarded). Called when allocations change.
  def sync_payment_status!
    return unless status == "requested" || status == "paid"

    target = paid_in_full? ? "paid" : "requested"
    update!(status: target) unless status == target
  end

  private

  def default_hours_from_event
    self.hours = event_registration&.event&.ce_hours if hours.blank? || hours.zero?
  end

  def calculate_amount
    self.amount_cents = (hours.to_d * rate_cents).round
  end

  def license_belongs_to_registrant
    return if professional_license.blank? || event_registration.blank?
    return if professional_license.person_id == event_registration.registrant_id

    errors.add(:professional_license, "must belong to the registrant")
  end
end
