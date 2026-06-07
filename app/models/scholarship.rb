class Scholarship < ApplicationRecord
  belongs_to :recipient, class_name: "Person"
  belongs_to :grant, optional: true
  has_one :allocation, as: :source, dependent: :destroy

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :recipient_must_match_allocation_registrant
  validate :within_grant_budget, if: :grant

  after_update :sync_allocation_amount, if: -> { saved_change_to_tasks_completed? || saved_change_to_amount_cents? }

  scope :completed, -> { where(tasks_completed: true) }

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end

  private

  def within_grant_budget
    return unless amount_cents

    others_total = grant.scholarships.where.not(id: id).sum(:amount_cents)
    if others_total + amount_cents > grant.amount_cents
      errors.add(:amount_cents, "would exceed the grant's available funds")
    end
  end

  def recipient_must_match_allocation_registrant
    return unless allocation&.allocatable.respond_to?(:registrant)

    if recipient != allocation.allocatable.registrant
      errors.add(:recipient, "must be the same person as the event registration's registrant")
    end
  end

  def sync_allocation_amount
    return unless allocation

    new_amount = tasks_completed? && amount_cents.to_i > 0 ? amount_cents : 0
    allocation.update!(amount: new_amount)
  end
end
