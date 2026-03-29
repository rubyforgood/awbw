class Payment < ApplicationRecord
  has_many :allocations, as: :source
  has_many :refunds, as: :refundable
  belongs_to :payer, polymorphic: true

  validates :amount_cents, numericality: true
  validates :currency, presence: true
end
