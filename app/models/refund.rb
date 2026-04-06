class Refund < ApplicationRecord
  attr_accessor :amount_dollars

  belongs_to :refundable, polymorphic: true
  belongs_to :recipient, polymorphic: true
  has_many :allocations, as: :source

  validates :amount_cents, numericality: true

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end
end
