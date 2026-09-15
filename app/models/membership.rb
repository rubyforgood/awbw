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

  # The admin overview's sections, in display order: the index's default query is
  # :overdue. Keys double as Membership scopes and section_invoice keys.
  OVERVIEW_SECTIONS = {
    overdue: "Overdue",
    within_grace: "Grace period",
    upcoming: "Upcoming",
    current: "Current"
  }.freeze

  has_paper_trail

  belongs_to :person
  has_many :membership_invoices, -> { order(start_date: :desc) }, dependent: :destroy

  accepts_nested_attributes_for :membership_invoices

  # When nil, charge standard cost. A value is an override
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :one_uncancelled_membership_per_person

  scope :not_cancelled, -> { where(cancelled_at: nil) }
  scope :cancelled, -> { where.not(cancelled_at: nil) }

  # Memberships with an invoice active on the given date.
  scope :current, ->(as_of = Date.current) {
    where(id: MembershipInvoice.active_on(as_of).select(:membership_id))
  }

  # Memberships with a future-starting invoice (e.g. a pre-issued renewal).
  scope :upcoming, ->(as_of = Date.current) {
    where(id: MembershipInvoice.where("start_date > ?", as_of).select(:membership_id))
  }

  # Memberships with an unpaid invoice whose start is within the grace window.
  scope :within_grace, ->(as_of = Date.current) {
    where(id: MembershipInvoice.not_paid_in_full
      .where("start_date >= ?", as_of - GRACE_PERIOD_DAYS)
      .select(:membership_id))
  }

  # Memberships with an unpaid invoice past the grace window.
  scope :overdue, ->(as_of = Date.current) {
    where(id: MembershipInvoice.overdue(as_of).select(:membership_id))
  }

  after_update :cancel_stripe_subscription, if: :saved_change_to_cancelled_at?
  after_update :expire_unbilled_future_invoices, if: :saved_change_to_cancelled_at?

  def cancelled? = cancelled_at.present?
  alias_method :cancelled, :cancelled?

  def cancelled=(value)
    flag = ActiveModel::Type::Boolean.new.cast(value)
    self.cancelled_at = flag ? (cancelled_at || Time.current) : nil
  end

  def cost_dollars
    cost_cents.to_d / 100 if cost_cents
  end

  def cost_dollars=(value)
    self.cost_cents = value.present? ? (value.to_d * 100).to_i : nil
  end

  def good_through
    membership_invoices.active_on(Date.current).unscope(:order).first&.end_date
  end

  def covered_on?(date = Date.current)
    membership_invoices.any? { |invoice| invoice.active_on?(date) }
  end

  def current_invoice
    membership_invoices.find { |invoice| invoice.active_on?(Date.current) } || membership_invoices.first
  end

  # The invoice that puts this membership in the given overview section, or nil.
  # Computed over the preloaded invoices so the admin index pays no per-row query.
  def section_invoice(section_key, as_of: Date.current)
    case section_key.to_sym
    when :current then membership_invoices.find { |invoice| invoice.active_on?(as_of) }
    when :upcoming then membership_invoices.find { |invoice| invoice.start_date && invoice.start_date > as_of }
    when :within_grace then membership_invoices.find { |invoice| invoice.within_grace?(as_of) }
    when :overdue then membership_invoices.find { |invoice| invoice.overdue?(as_of) }
    end
  end

  def stripe_subscription
    return if person.blank?

    person.pay_subscriptions.find { |sub| sub.metadata&.dig("membership_id").to_i == id }
  end

  private

  def expire_unbilled_future_invoices
    return unless cancelled_at.present?
    membership_invoices.where("start_date > ?", Date.current).each do |invoice|
      invoice.destroy! if invoice.allocations.none?
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
