class MembershipChargeAttempt < ApplicationRecord
  MAX_ATTEMPTS = 7
  RETRY_WINDOW_DAYS = MAX_ATTEMPTS - 1

  TERMINAL_STATUSES = %w[succeeded failed needs_action unknown needs_card].freeze
  STATUSES = (%w[pending] + TERMINAL_STATUSES).freeze

  belongs_to :membership_invoice
  belongs_to :pay_charge, class_name: "Pay::Charge", optional: true

  validates :attempt_number, presence: true, uniqueness: { scope: :membership_invoice_id }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(attempt_number: :desc) }

  def terminal? = TERMINAL_STATUSES.include?(status)
  def pending? = status == "pending"
  def succeeded? = status == "succeeded"
  def failed? = status == "failed"
  def needs_action? = status == "needs_action"
  def needs_card? = status == "needs_card"
  def unknown? = status == "unknown"
end
