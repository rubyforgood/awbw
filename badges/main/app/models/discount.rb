class Discount < ApplicationRecord
  has_many :allocations, as: :source, dependent: :destroy

  validates :amount_cents, numericality: { greater_than: 0 }

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end
end
