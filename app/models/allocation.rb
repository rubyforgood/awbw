class Allocation < ApplicationRecord
  attr_accessor :amount_dollars

  belongs_to :source, polymorphic: true
  belongs_to :allocatable, polymorphic: true
  validates :amount, numericality: true

  def amount_dollars
    amount.to_d / 100 if amount
  end

  def amount_dollars=(value)
    self.amount = (value.to_d * 100).to_i if value.present?
  end
end
