class Membership < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # TODO enable for production when the full membership feature is complete
  def self.enabled?
    !Rails.env.production?
  end

  TIME_ZONE = "Pacific Time (US & Canada)".freeze
  INVOICE_PERIOD = 1.year

  ANNUAL_COST_CENTS = ENV.fetch("ANNUAL_MEMBERSHIP_CENTS", 2500).to_i
  GRACE_PERIOD_DAYS = ENV.fetch("ANNUAL_MEMBERSHIP_GRACE_PERIOD_DAYS", 30).to_i
  RENEWAL_WINDOW_DAYS = ENV.fetch("ANNUAL_MEMBERSHIP_RENEWAL_WINDOW_DAYS", 30).to_i

  attr_accessor :end_coverage_today

  has_paper_trail

  belongs_to :person
  has_many :membership_invoices, -> { order(start_date: :desc) }, dependent: :destroy

  accepts_nested_attributes_for :membership_invoices

  # When nil, charge standard cost. A value is an override
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :one_uncancelled_membership_per_person

  scope :not_cancelled, -> { where(cancelled_at: nil) }
  scope :cancelled, -> { where.not(cancelled_at: nil) }

  after_update :cancel_stripe_subscription, if: :saved_change_to_cancelled_at?
  after_save :apply_end_coverage_today, if: :end_coverage_today?

  def cancelled? = cancelled_at.present?
  alias_method :cancelled, :cancelled?

  def cancelled=(value)
    flag = ActiveModel::Type::Boolean.new.cast(value)
    self.cancelled_at = flag ? (cancelled_at || Time.current) : nil
  end

  # Admin "Cancel now": end the current invoice's coverage at the end of today
  # and drop any already-minted future year that is still unbilled. The paired
  # cancelled="1" param cancels the Stripe subscription via cancel_stripe_subscription.
  def end_coverage_today=(value)
    @end_coverage_today = ActiveModel::Type::Boolean.new.cast(value)
  end

  def end_coverage_today? = !!@end_coverage_today

  def cost_dollars
    cost_cents.to_d / 100 if cost_cents
  end

  def cost_dollars=(value)
    self.cost_cents = value.present? ? (value.to_d * 100).to_i : nil
  end

  def good_through
    membership_invoices.active_on(Date.current).unscope(:order).first&.end_date
  end

  def stripe_subscription
    return if person.blank?

    person.pay_subscriptions.find { |sub| sub.metadata&.dig("membership_id").to_i == id }
  end

  private

  def apply_end_coverage_today
    transaction do
      membership_invoices.active_on(Date.current).first&.update!(end_date: Date.current)
      membership_invoices.where("start_date > ?", Date.current).each do |invoice|
        invoice.destroy! if invoice.allocations.none?
      end
    end
  end

  def cancel_stripe_subscription
    return unless cancelled_at.present?

    sub = stripe_subscription
    return unless sub&.active?

    sub.cancel_now! # `now!` prevents customer from reactivating in stripe portal. Must create new subscription if admin allows
  rescue Stripe::StripeError, Pay::Error => e
    Rails.logger.warn("[Membership] Could not cancel Stripe subscription for membership #{id}: #{e.message}")
  end

  def one_uncancelled_membership_per_person
    return if cancelled_at.present? || person_id.blank?

    others = Membership.not_cancelled.where(person_id: person_id)
    others = others.where.not(id: id) if persisted?
    return unless others.exists?

    errors.add(:base, "This person already has a membership that hasn't been cancelled")
  end
end
