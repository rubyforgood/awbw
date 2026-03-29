class Refund < ApplicationRecord
  belongs_to :refundable, polymorphic: true
  belongs_to :recipient, polymorphic: true
  has_many :allocations, as: :source

  validates :amount_cents, numericality: true
end
