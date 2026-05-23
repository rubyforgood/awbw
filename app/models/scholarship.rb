class Scholarship < ApplicationRecord
  belongs_to :event_registration
  has_many :allocations, as: :source, dependent: :destroy

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }

  after_save :sync_allocation

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

  private

  def sync_allocation
    if tasks_completed? && amount_cents.to_i > 0
      allocations.find_or_initialize_by(allocatable: event_registration)
                 .update!(amount: amount_cents)
    elsif !tasks_completed?
      allocations.where(allocatable: event_registration).destroy_all
    end
  end
end
