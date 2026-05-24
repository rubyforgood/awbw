class Scholarship < ApplicationRecord
  has_many :allocations, as: :source, dependent: :destroy

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }

  after_update :sync_allocation_amount, if: -> { saved_change_to_tasks_completed? || saved_change_to_amount_cents? }

  scope :completed, -> { where(tasks_completed: true) }

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end

  def allocatable
    allocations.first&.allocatable
  end

  private

  def sync_allocation_amount
    allocation = allocations.first
    return unless allocation

    new_amount = tasks_completed? && amount_cents.to_i > 0 ? amount_cents : 0
    allocation.update!(amount: new_amount)
  end
end
