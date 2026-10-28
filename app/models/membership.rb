class Membership < ApplicationRecord
  include PersonNameSearchable

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  def self.enabled?
    !Rails.env.production?
  end

  TIME_ZONE = "Pacific Time (US & Canada)".freeze
  CURRENCY = "usd".freeze
  INVOICE_PERIOD = 1.year

  def self.annual_cost_cents = Setting.annual_membership_cents
  def self.renewal_window_days = Setting.membership_renewal_window_days

  DIRECTORY_STATUSES = %w[active ending upcoming ended all].freeze

  has_paper_trail

  belongs_to :person
  has_many :membership_invoices, -> { order(start_date: :desc) }, dependent: :destroy

  validates :start_date, :end_date, presence: true
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :end_date_after_start_date
  validate :no_overlapping_membership_dates

  scope :autorenewal_not_cancelled, -> { where(autorenewal_cancelled_at: nil) }
  scope :unlocked, -> { where(locked_at: nil) }

  scope :active, ->(as_of = Date.current) {
    where(autorenewal_cancelled_at: nil)
      .where(start_date: ..as_of, end_date: as_of..)
  }
  scope :ending, ->(as_of = Date.current) {
    where.not(autorenewal_cancelled_at: nil)
      .where(start_date: ..as_of, end_date: as_of..)
  }
  scope :upcoming, ->(as_of = Date.current) { where("start_date > ?", as_of) }
  scope :ended, ->(as_of = Date.current) { where(end_date: ...as_of) }

  attr_accessor :skip_deletion_guard, :first_invoice_cost_dollars

  before_destroy :prepare_destroy, prepend: true

  def locked? = locked_at.present?
  def renewal_on? = autorenewal_cancelled_at.nil?
  def autorenewal_cancelled? = !renewal_on?
  def autopay_on? = person&.autopay_on? || false

  def autorenewal_cancelled=(value)
    flag = ActiveModel::Type::Boolean.new.cast(value)
    self.autorenewal_cancelled_at = flag ? (autorenewal_cancelled_at || Time.current) : nil
  end

  def active? = start_date.present? && start_date <= Date.current && end_date.present? && end_date >= Date.current

  def upcoming?
    start_date.present? && start_date > Date.current
  end

  def upcoming_start_date = start_date

  def owes? = invoices_due.any?

  def ended? = end_date.present? && end_date < Date.current

  def cost_dollars
    cost_cents.to_d / 100 if cost_cents
  end

  def cost_dollars=(value)
    self.cost_cents = value.present? ? (value.to_d * 100).to_i : nil
  end

  def next_invoice
    membership_invoices.where("start_date > ?", Date.current).order(:start_date).first
  end

  def invoices_due
    membership_invoices.not_paid_in_full.where(start_date: ..Date.current)
  end

  def deletable? = membership_invoices.none?

  def discardable?
    membership_invoices.one? && discard_blocked_reason.nil?
  end

  def discard_blocked_reason
    invoices = membership_invoices.to_a
    return "it has no invoices" if invoices.empty?
    return "it has more than one invoice" unless invoices.one?

    invoice = invoices.first
    return "its invoice has payments or credits applied" unless invoice.allocations.sum(:amount).zero?
    return "its invoice has a payment in progress" if invoice.payment_in_progress?
    return "its invoice has a pending charge attempt" if invoice.charge_attempts.pending.exists?

    nil
  end

  def deletion_blocked_reason
    return "it has invoices" if membership_invoices.exists?

    nil
  end

  def remove_next_year!
    invoice = next_invoice
    return false if invoice.blank?
    return false unless invoice.start_date > Date.current
    return false if invoice.payment_in_progress?
    return false unless invoice.allocations.sum(:amount).zero?
    return false unless invoice.other_invoices?

    removed_end = invoice.end_date
    invoice.destroy!

    if end_date == removed_end
      previous_end = membership_invoices.reload.maximum(:end_date)
      update_column(:end_date, previous_end) if previous_end
    end

    update_column(:autorenewal_cancelled_at, Time.current)
    true
  end

  def lock_for_history!
    transaction do
      begin
        remove_next_year!
      rescue ActiveRecord::RecordNotDestroyed
      end
      update!(locked_at: Time.current, autorenewal_cancelled_at: autorenewal_cancelled_at || Time.current)
    end
  end

  private

  def prepare_destroy
    unless skip_deletion_guard
      unless deletable?
        errors.add(:base, "Cannot delete this membership because #{deletion_blocked_reason}.")
        throw :abort
      end
    end

    membership_invoices.each { |invoice| invoice.skip_deletion_guard = true }
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
end
