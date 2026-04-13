class Payment < ApplicationRecord
  has_many :allocations, as: :source
  has_many :refunds, as: :refundable
  belongs_to :payer, polymorphic: true

  validates :amount_cents, numericality: true
  validates :currency, presence: true

  before_validation :set_amount_cents_remaining, if: :new_record?

  scope :by_type, ->(types) {
    return if types.blank?
    types = types.split(",") if types.is_a?(String)
    types = types.reject(&:blank?)
    where(type: types) if types.present?
  }
  scope :by_payer, ->(payer_type, payer_id) { where(payer_type: payer_type, payer_id: payer_id) if payer_type.present? && payer_id.present? }
  scope :has_remaining, ->(value) {
    case value
    when "yes" then where("amount_cents_remaining > 0")
    when "no" then where("amount_cents_remaining = 0")
    end
  }

  def self.search_by_params(params)
    results = all
    results = results.by_type(params[:type]) if params[:type].present?
    results = results.by_payer(params[:payer_type], params[:payer_id]) if params[:payer_type].present? && params[:payer_id].present?
    results = results.has_remaining(params[:has_remaining]) if params[:has_remaining].present? && params[:has_remaining] != "all"
    results
  end

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end

  def allocated_dollars
    (amount_cents - (amount_cents_remaining || 0)).to_d / 100
  end

  def allocated_dollars=(value)
    self.amount_cents_remaining = ((amount_cents || 0) - (value.to_d * 100).to_i) if value.present?
  end

  def remaining_dollars
    amount_cents_remaining.to_d / 100 if amount_cents_remaining
  end

  def remaining_dollars=(value)
    self.amount_cents_remaining = (value.to_d * 100).to_i if value.present?
  end

  private

  def set_amount_cents_remaining
    self.amount_cents_remaining = amount_cents if amount_cents_remaining.nil? && amount_cents.present?
  end
end
