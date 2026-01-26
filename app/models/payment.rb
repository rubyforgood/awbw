class Payment < ApplicationRecord
  # --- Associations ---
  belongs_to :payer,   polymorphic: true
  belongs_to :payable, polymorphic: true

  # --- Callbacks ---
  attribute :currency, :string, default: "usd"
  attribute :status,   :string, default: "pending"

  # --- Validations ---
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :status, presence: true
  validates :stripe_payment_intent_id, presence: true

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

  scope :for_payable, ->(payable) { where(payable: payable) }
  scope :successful,  -> { where(status: "succeeded") }
  scope :pendingish,  -> { where(status: %w[pending requires_action processing]) }
end
