class Allocation < ApplicationRecord
  attr_accessor :amount_dollars

  belongs_to :source, polymorphic: true
  belongs_to :allocatable, polymorphic: true
  belongs_to :reverted, class_name: "Allocation", optional: true

  has_one :revert_record, class_name: "Allocation", foreign_key: "reverted_id", inverse_of: :reverted

  validates :amount, numericality: true

  validate :reverted_requires_positive_amount, :negative_cannot_be_reverted

  def reverted?
    reverted_id.present?
  end

  def amount_dollars
    amount.to_d / 100 if amount
  end

  def amount_dollars=(value)
    self.amount = (value.to_d * 100).to_i if value.present?
  end

  private

  def reverted_requires_positive_amount
    if reverted_id.present? && amount.to_i <= 0
      errors.add(:reverted_id, "must be on a positive amount allocation")
    end
  end

  def negative_cannot_be_reverted
    if amount.to_i < 0 && reverted_id.present?
      errors.add(:amount, "cannot be negative when reverting another allocation")
    end
  end
end
