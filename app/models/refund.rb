class Refund < ApplicationRecord
  METHODS = %w[check cash stripe].freeze

  belongs_to :refundable, polymorphic: true
  belongs_to :recipient, polymorphic: true
  has_many :allocations, as: :source

  validates :amount_cents, numericality: true
  validates :method, inclusion: { in: METHODS }
  validates :stripe_refund_id, uniqueness: true, allow_nil: true

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end
end
