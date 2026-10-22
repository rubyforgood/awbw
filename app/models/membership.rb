class Membership < ApplicationRecord
  include PersonNameSearchable

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # TODO enable for production when the full membership feature is complete
  def self.enabled?
    !Rails.env.production?
  end

  TIME_ZONE = "Pacific Time (US & Canada)".freeze
  INVOICE_PERIOD = 1.year

  # Methods, not constants: these read the Setting row, and a constant would run
  # that query while the class loads — before the table exists during migration.
  def self.annual_cost_cents = Setting.annual_membership_cents
  def self.renewal_window_days = Setting.membership_renewal_window_days

  DIRECTORY_STATUSES = %w[active ending lapsed ended all].freeze

  has_paper_trail

  belongs_to :person
  has_many :membership_invoices, -> { order(start_date: :desc) }, dependent: :destroy

  accepts_nested_attributes_for :membership_invoices

  # When nil, charge standard cost. A value is an override
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :one_active_membership_per_person
  validate :end_date_after_start_date
  validate :no_overlapping_membership_dates

  scope :autorenewal_not_cancelled, -> { where(autorenewal_cancelled_at: nil) }

  scope :active, ->(as_of = Date.current) {
    where(autorenewal_cancelled_at: nil).where(end_date: as_of..).where(start_date: ..as_of)
  }
  scope :ending, ->(as_of = Date.current) {
    where.not(autorenewal_cancelled_at: nil).where(end_date: as_of..).where(start_date: ..as_of)
  }
  scope :lapsed, ->(as_of = Date.current) {
    where("end_date IS NULL OR end_date < ?", as_of)
      .where(id: MembershipInvoice.overdue(as_of).select(:membership_id))
  }
  scope :ended, ->(as_of = Date.current) {
    where("end_date IS NULL OR end_date < ?", as_of)
      .where.not(id: MembershipInvoice.overdue(as_of).select(:membership_id))
  }

  after_update :cancel_stripe_subscription, if: :just_autorenewal_cancelled?
  after_update :expire_unbilled_future_invoices, if: :just_autorenewal_cancelled?
  before_destroy :prepare_destroy, prepend: true
  before_destroy :cancel_stripe_subscription

  def active? = start_date.present? && start_date <= Date.current && end_date.present? && end_date >= Date.current

  def upcoming? = start_date.present? && start_date > Date.current

  def owes? = membership_invoices.any?(&:overdue?)

  def ended? = !active? && !owes? && !upcoming?

  def renewal_in_flight?
    return false unless person.payment_processor&.subscribed?

    invoice = current_invoice
    invoice&.overdue? && invoice.start_date >= Date.current - 1.day
  end

  def autorenewal_cancelled? = autorenewal_cancelled_at.present?

  def autorenewal_cancelled=(value)
    flag = ActiveModel::Type::Boolean.new.cast(value)
    self.autorenewal_cancelled_at = flag ? (autorenewal_cancelled_at || Time.current) : nil
  end

  def cost_dollars
    cost_cents.to_d / 100 if cost_cents
  end

  def cost_dollars=(value)
    self.cost_cents = value.present? ? (value.to_d * 100).to_i : nil
  end



  def covered_on?(date = Date.current)
    membership_invoices.any? { |invoice| invoice.active_on?(date) }
  end

  def current_invoice
    membership_invoices.find { |invoice| invoice.active_on?(Date.current) } || membership_invoices.first
  end

  # Invoices that still owe money (comped and paid ones excluded), newest first —
  # what the profile card lists.
  def invoices_due
    membership_invoices.not_paid_in_full
  end

  def stripe_subscription
    return if person.blank?

    person.pay_subscriptions.find { |sub| sub.metadata&.dig("membership_id").to_i == id }
  end

  def deletable?
    deletion_blocked_reason.nil?
  end

  def deletion_blocked_reason
    return "it has invoices with payments or credits applied" if membership_invoices.joins(:allocations).exists?

    nil
  end

  attr_accessor :skip_deletion_guard

  # Update membership start_date/end_date from a newly created paid or free invoice.
  # Called from MembershipInvoice after_save. Only increases dates; never decreases.
  def sync_dates_from_invoice(invoice)
    return unless invoice.paid_in_full?

    new_start = invoice.start_date
    new_end = invoice.end_date
    changed = false

    if start_date.blank? || (new_start && new_start < start_date)
      self.start_date = new_start
      changed = true
    end

    if end_date.blank? || (new_end && new_end > end_date)
      self.end_date = new_end
      changed = true
    end

    save(validate: false, touch: false) if changed
  end

  private

  def just_autorenewal_cancelled?
    saved_change_to_autorenewal_cancelled_at? && autorenewal_cancelled_at.present?
  end

  def prepare_destroy
    unless skip_deletion_guard
      unless deletable?
        errors.add(:base, "Cannot delete this membership because #{deletion_blocked_reason}.")
        throw :abort
      end
    end

    membership_invoices.each { |invoice| invoice.skip_deletion_guard = true }
  end

  def expire_unbilled_future_invoices
    return unless autorenewal_cancelled_at.present?
    membership_invoices.where("start_date > ?", Date.current).each do |invoice|
      next unless invoice.allocations.none?

      invoice.skip_deletion_guard = true
      invoice.destroy!
    end
  end

  def cancel_stripe_subscription
    sub = stripe_subscription
    return unless sub&.active?

    sub.cancel_now! # `now!` prevents customer from reactivating in stripe portal. Must create new subscription if admin allows
  rescue Stripe::StripeError, Pay::Error => e
    Rails.logger.warn("[Membership] Could not cancel Stripe subscription for membership #{id}: #{e.message}")
  end

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be after the start date") if end_date < start_date
  end

  def no_overlapping_membership_dates
    return if start_date.blank? || end_date.blank? || person_id.blank?

    overlapping = Membership.where(person_id: person_id)
      .where.not(id: id)
      .where("start_date < ? AND end_date > ?", end_date, start_date)
    return unless overlapping.exists?

    errors.add(:base, "This membership overlaps with an existing membership for this person")
  end

  def one_active_membership_per_person
    return if autorenewal_cancelled_at.present? || person_id.blank?

    others = Membership.autorenewal_not_cancelled.where(person_id: person_id)
    others = others.where.not(id: id) if persisted?
    return unless others.exists?

    errors.add(:base, "This person already has a membership that is active")
  end
end
