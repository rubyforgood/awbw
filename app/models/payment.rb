class Payment < ApplicationRecord
  attr_accessor :amount_dollars, :remaining_dollars

  has_many :allocations, as: :source
  has_many :refunds, as: :refundable
  belongs_to :payer, polymorphic: true

  validates :amount_cents, numericality: true
  validates :currency, presence: true

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end

  def allocated_dollars
    (amount_cents - (amount_cents_remaining || 0)).to_d / 100
  end

  def allocated_dollars=(value)
    self.amount_cents_remaining = ((amount_cents || 0) - (value.to_d * 100).to_i) if value.present?
  end

  def remaining_dollars
    amount_cents_remaining.to_d / 100 if amount_cents_remaining
  end

  def remaining_dollars=(value)
    self.amount_cents_remaining = (value.to_d * 100).to_i if value.present?
  end
end
