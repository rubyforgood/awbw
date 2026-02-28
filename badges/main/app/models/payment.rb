class Payment < ApplicationRecord
  # --- Associations ---
  belongs_to :payer,   polymorphic: true
  belongs_to :payable, polymorphic: true
  belongs_to :event, optional: true

  # --- Callbacks ---
  attribute :currency, :string, default: "usd"
  attribute :status,   :string, default: "pending"

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

  scope :for_payable,  ->(payable) { where(payable: payable) }
  scope :successful,   -> { where(status: "succeeded") }
  scope :pendingish,   -> { where(status: %w[pending requires_action processing]) }
  scope :scholarships, -> { where(payment_type: "scholarship") }
  scope :refunds, -> { where(payment_type: "refund") }

  def scholarship?
    payment_type == "scholarship"
  end
end
