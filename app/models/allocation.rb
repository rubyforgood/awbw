class Allocation < ApplicationRecord
  belongs_to :source, polymorphic: true
  belongs_to :allocatable, polymorphic: true
  belongs_to :reverted, class_name: "Allocation", optional: true

  has_one :revert_record, class_name: "Allocation", foreign_key: "reverted_id", inverse_of: :reverted

  validates :amount, numericality: true
  validates :allocatable_type, presence: true
  validates :allocatable_id, presence: true

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

  scope :by_source_type, ->(types) {
    return if types.blank?
    types = types.split(",") if types.is_a?(String)
    types = types.reject(&:blank?)
    return unless types.present?

    payment_types = types.select { |t| %w[CashPayment CheckPayment ExternalProcessorPayment].include?(t) }
    non_payment_types = types - payment_types

    conditions = []
    binds = []

    if payment_types.any?
      conditions << "(source_type = 'Payment' AND EXISTS (SELECT 1 FROM payments WHERE payments.id = allocations.source_id AND payments.type IN (?)))"
      binds << payment_types
    end

    non_payment_types.each do |type|
      conditions << "(source_type = ?)"
      binds << type
    end

    where(conditions.join(" OR "), *binds) if conditions.any?
  }
  scope :by_allocatable_type, ->(type) { where(allocatable_type: type) if type.present? }
  scope :has_reverted, ->(value) {
    case value
    when "yes" then where("reverted_id IS NOT NULL OR amount < 0")
    when "no" then where("reverted_id IS NULL AND amount >= 0")
    end
  }
  scope :by_allocatable_id, ->(allocatable_type, allocatable_id) {
    where(allocatable_type: allocatable_type, allocatable_id: allocatable_id) if allocatable_type.present? && allocatable_id.present?
  }

  def self.search_by_params(params)
    results = all
    results = results.by_source_type(params[:source_type]) if params[:source_type].present?
    results = results.by_allocatable_type(params[:allocatable_type]) if params[:allocatable_type].present?
    results = results.has_reverted(params[:has_reverted]) if params[:has_reverted].present? && params[:has_reverted] != "all"
    if params[:payer_type].present? || params[:person_id].present? || params[:organization_id].present?
      payment_ids = Payment.all
      payment_ids = payment_ids.where(payer_type: params[:payer_type]) if params[:payer_type].present?
      payment_ids = payment_ids.where(person_id: params[:person_id]) if params[:person_id].present?
      payment_ids = payment_ids.where(organization_id: params[:organization_id]) if params[:organization_id].present?
      results = results.where("source_type LIKE ? AND source_id IN (?)", "%Payment", payment_ids.select(:id))
    end
    results = results.by_allocatable_id(params[:allocatable_type], params[:allocatable_id]) if params[:allocatable_type].present? && params[:allocatable_id].present?
    results
  end

  private

  def reverted_requires_positive_amount
    if reverted_id.present? && amount.to_i < 0
      errors.add(:reverted_id, "must be on a positive amount allocation")
    end
  end

  def negative_cannot_be_reverted
    if amount.to_i < 0 && reverted_id.present?
      errors.add(:amount, "cannot be negative when reverting another allocation")
    end
  end
end
