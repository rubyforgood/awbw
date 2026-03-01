class Payment < ApplicationRecord
  # --- Associations ---
  belongs_to :payer, class_name: "Person"
  belongs_to :event, optional: true
  belongs_to :organization, optional: true
  has_many :event_registrations, dependent: :nullify

  # --- Attributes ---
  attribute :currency, :string, default: "usd"
  attribute :status,   :string, default: "pending"

  normalizes :stripe_payment_intent_id, :stripe_charge_id, with: ->(v) { v.presence }

  PAYMENT_TYPES = %w[ stripe scholarship check purchase_order other refund ].freeze

  # --- Validations ---
  validates :amount_cents, numericality: true
  validates :currency, presence: true
  validates :status, presence: true
  validates :payment_type, inclusion: { in: PAYMENT_TYPES }
  validates :stripe_payment_intent_id, presence: true, if: -> { payment_type == "stripe" }

  validates :stripe_payment_intent_id, uniqueness: true, allow_nil: true
  validates :stripe_charge_id, uniqueness: true, allow_nil: true

  STRIPE_PAYMENT_STATUSES = %w[
    pending
    requires_action
    processing
    succeeded
    failed
    canceled
    refunded
    partially_refunded
  ].freeze

  validates :status, inclusion: { in: STRIPE_PAYMENT_STATUSES }

  scope :successful,   -> { where(status: "succeeded") }
  scope :pendingish,   -> { where(status: %w[pending requires_action processing]) }
  scope :scholarships, -> { where(payment_type: "scholarship") }
  scope :refunds,      -> { where(payment_type: "refund") }
  scope :by_status,    ->(status) { where(status: status) }

  def succeeded?
    status == "succeeded"
  end

  def scholarship?
    payment_type == "scholarship"
  end

  def self.search_by_params(params)
    scope = is_a?(ActiveRecord::Relation) ? self : all
    scope = scope.by_status(params[:status]) if params[:status].present?
    scope = scope.where(payer_id: params[:payer_id]) if params[:payer_id].present?
    scope = scope.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    if params[:event_id].present?
      scope = scope.joins(:event_registrations).where(event_registrations: { event_id: params[:event_id] }).distinct
    end
    scope
  end
end
