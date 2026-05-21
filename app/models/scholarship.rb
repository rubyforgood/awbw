class Scholarship < ApplicationRecord
  belongs_to :event_registration
  has_many :allocations, as: :source, dependent: :destroy

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :completed, -> { where(tasks_completed: true) }

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end

  def allocated?
    allocations.exists?
  end

  def can_allocate?
    tasks_completed? && !allocated? && amount_cents.to_i > 0
  end

  def allocate!
    raise "Cannot allocate" unless can_allocate?

    remaining = event_registration.remaining_cost
    raise "Event already paid in full" if remaining <= 0

    allocations.create!(allocatable: event_registration, amount: [amount_cents, remaining].min)
  end
end
