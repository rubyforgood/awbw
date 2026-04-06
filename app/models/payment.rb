class Payment < ApplicationRecord
  attr_accessor :amount_dollars

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
end
