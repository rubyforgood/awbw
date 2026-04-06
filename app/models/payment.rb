class Payment < ApplicationRecord
  attr_accessor :amount_dollars, :allocated_dollars

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
    allocated_amount_cents.to_d / 100 if allocated_amount_cents
  end

  def allocated_dollars=(value)
    self.allocated_amount_cents = (value.to_d * 100).to_i if value.present?
  end

  def unallocated_amount_cents
    amount_cents - (allocated_amount_cents || 0)
  end

  def unallocated_dollars
    unallocated_amount_cents.to_d / 100
  end
end
