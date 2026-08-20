class Refund < ApplicationRecord
  has_paper_trail
  METHODS = %w[check cash stripe].freeze

  belongs_to :refundable, polymorphic: true
  belongs_to :recipient, polymorphic: true
  has_many :allocations, as: :source

  validates :amount_cents, numericality: true
  validates :method, inclusion: { in: METHODS }
  validates :stripe_refund_id, uniqueness: true, allow_nil: true

  after_create :adjust_payment_remaining
  after_destroy :reverse_payment_remaining

  def adjust_payment_remaining
    refundable.update!(amount_cents_remaining: refundable.amount_cents_remaining - amount_cents)
  end

  def reverse_payment_remaining
    refundable.update!(amount_cents_remaining: refundable.amount_cents_remaining + amount_cents)
  end

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end
end
