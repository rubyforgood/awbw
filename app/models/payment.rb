class Payment < ApplicationRecord
  PAYER_TYPES = %w[Person Organization].freeze

  has_many :allocations, as: :source
  has_many :refunds, as: :refundable
  belongs_to :person, optional: true
  belongs_to :organization, optional: true

  validates :amount_cents, numericality: true
  validates :currency, presence: true
  validates :payer_type, presence: true, inclusion: { in: PAYER_TYPES }

  validate :at_least_one_payer

  before_validation :set_amount_cents_remaining, if: :new_record?
  before_validation :auto_set_payer_type

  scope :by_type, ->(types) {
    return if types.blank?
    types = types.split(",") if types.is_a?(String)
    types = types.reject(&:blank?)
    where(type: types) if types.present?
  }
  scope :has_remaining, ->(value) {
    case value
    when "yes" then where("amount_cents_remaining > 0")
    when "no" then where("amount_cents_remaining = 0")
    end
  }

  def self.search_by_params(params)
    results = all
    results = results.by_type(params[:type]) if params[:type].present?
    results = results.where(payer_type: params[:payer_type]) if params[:payer_type].present?
    results = results.where(person_id: params[:person_id]) if params[:person_id].present?
    results = results.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    results = results.has_remaining(params[:has_remaining]) if params[:has_remaining].present? && params[:has_remaining] != "all"
    results
  end

  def payer
    case payer_type
    when "Organization" then organization
    else person
    end
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

  def auto_set_payer_type
    if person_id.present? && organization_id.blank?
      self.payer_type = "Person"
    elsif organization_id.present? && person_id.blank?
      self.payer_type = "Organization"
    end
  end

  def at_least_one_payer
    if person_id.blank? && organization_id.blank?
      errors.add(:base, "At least one payer (person or organization) must be present")
    end
  end
end
