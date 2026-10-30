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
  validate :term_within_invoice_coverage, if: :persisted?

  scope :renewal_on, -> { where(renewal_off_at: nil) }
  scope :unlocked, -> { where(locked_at: nil) }

  scope :active, ->(as_of = Date.current) {
    where(renewal_off_at: nil)
      .where(start_date: ..as_of, end_date: as_of..)
  }
  scope :ending, ->(as_of = Date.current) {
    where.not(renewal_off_at: nil)
      .where(start_date: ..as_of, end_date: as_of..)
  }
  scope :upcoming, ->(as_of = Date.current) { where("start_date > ?", as_of) }
  scope :ended, ->(as_of = Date.current) { where(end_date: ...as_of) }

  attr_accessor :skip_deletion_guard, :first_invoice_cost_dollars

  before_save :disable_autopay_when_renewal_off, if: :renewal_off?
  before_destroy :prepare_destroy, prepend: true

  def locked? = locked_at.present?
  def renewal_on? = renewal_off_at.nil?
  def renewal_off? = !renewal_on?

  def active? = start_date <= Date.current && end_date >= Date.current

  def upcoming? = start_date > Date.current

  def upcoming_start_date = start_date

  def owes?
    return @owes if defined?(@owes)

    @owes = membership_invoices.any? do |invoice|
      invoice.start_date <= Date.current && !invoice.paid_in_full?
    end
  end

  def ended? = end_date < Date.current

  def cost_dollars
    cost_cents.to_d / 100 if cost_cents
  end

  def cost_dollars=(value)
    self.cost_cents = value.present? ? (value.to_d * 100).to_i : nil
  end

  def next_invoice
    membership_invoices.where("start_date > ?", Date.current).order(:start_date).first
  end

  def next_autopay_invoice
    membership_invoices
      .not_paid_in_full
      .autopay_issued
      .order(:start_date)
      .first
  end

  def invoice_coverage_start = membership_invoices.minimum(:start_date)
  def invoice_coverage_end = membership_invoices.maximum(:end_date)

  # Renewal can run only while the term is current (or within the same one-day
  # grace Renew allows) and the term reaches the last issued invoice. Paid
  # coverage extending past an early-ended term must be reinstated first.
  def renewal_blocked_reason
    return "This membership has no end date. Edit the term first." if end_date.blank?

    if end_date < Date.current - 1.day
      return "This membership ended on #{end_date.strftime("%b %-d, %Y")}. Extend the term or create a new membership."
    end

    coverage_end = invoice_coverage_end
    return "This membership has no invoices to renew." if coverage_end.blank?

    if coverage_end > end_date
      return "An invoice covers through #{coverage_end.strftime("%b %-d, %Y")}. " \
             "Extend the term to at least that date before turning renewal on."
    end

    nil
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
    return "its invoice has payments or credits applied" unless invoice.allocations_sum.zero?
    return "its invoice has a payment in progress" if invoice.payment_in_progress?
    return "its invoice has an unresolved payment attempt" if invoice.unresolved_attempt?
  end

  def deletion_blocked_reason
    return "it has invoices" if membership_invoices.exists?
  end

  def lock_for_history!
    transaction do
      result = Membership::RemoveNextYear.call(membership: self)
      unless result.success?
        errors.add(:base, result.errors.to_sentence)
        raise ActiveRecord::RecordInvalid.new(self)
      end

      update!(locked_at: Time.current, renewal_off_at: renewal_off_at || Time.current)
    end
  end

  private

  def disable_autopay_when_renewal_off
    self.autopay_on = false
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

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be after the start date") if end_date < start_date
  end

  def no_overlapping_membership_dates
    return if start_date.blank? || end_date.blank? || person_id.blank?

    overlapping = Membership.where(person_id: person_id)
      .where.not(id: id)
      .where("start_date <= ? AND end_date >= ?", end_date, start_date)
    return unless overlapping.exists?

    errors.add(:base, "This membership overlaps with an existing membership for this person")
  end

  # The term is the source of truth for coverage, but it must stay within the
  # invoices: shorter is allowed (ending early), longer is not (issue an invoice
  # for added time). Skipped until the membership has invoices, so the create
  # flow can save the term before its first invoice.
  def term_within_invoice_coverage
    return if start_date.blank? || end_date.blank?

    first_start = invoice_coverage_start
    last_end = invoice_coverage_end
    return if first_start.blank? || last_end.blank?

    if start_date < first_start
      errors.add(:start_date, "can't be before the first invoice (#{first_start.strftime("%b %-d, %Y")})")
    end

    if end_date > last_end
      errors.add(:end_date, "can't be after the last invoice (#{last_end.strftime("%b %-d, %Y")})")
    end
  end
end
