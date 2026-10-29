class MembershipInvoice < ApplicationRecord
  include PersonNameSearchable, Registerable

  PAYMENT_TOKEN_PURPOSE = "membership_invoice_payment".freeze

  has_paper_trail

  belongs_to :membership
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :allocations, as: :allocatable, dependent: :destroy
  has_many :charge_attempts, -> { order(:attempt_number) },
           class_name: "MembershipChargeAttempt", dependent: :destroy

  belongs_to :invoicee, polymorphic: true, optional: true
  belongs_to :bill_to_address, class_name: "Address", optional: true
  belongs_to :attention_person, class_name: "Person", optional: true

  delegate :person, to: :membership
  alias_method :registrant, :person

  def self.person_name_join = { membership: :person }

  scope :active_on, ->(date = Date.current) { where(start_date: ..date, end_date: date..) }
  scope :expiring_between, ->(from, to) { where(end_date: from..to) }

  scope :paid_in_full, -> { where(cost_covered_by_allocations) }
  scope :not_paid_in_full, -> { where(chargeable.and(cost_covered_by_allocations.not)) }

  scope :overdue, ->(as_of = Date.current) {
    not_paid_in_full.where(start_date: ..as_of)
  }

  scope :with_positive_allocation, -> {
    where(id: Allocation.where(allocatable_type: polymorphic_name)
      .group(:allocatable_id)
      .having("SUM(amount) > 0")
      .select(:allocatable_id))
  }
  scope :partially_paid, -> { not_paid_in_full.with_positive_allocation }

  before_validation :derive_end_date, on: :create
  before_validation :inherit_invoice_details, on: :create
  before_destroy :prevent_destroy_unless_deletable
  after_save :clear_payment_in_progress, if: :paid_in_full?
  after_destroy :clamp_membership_term

  validates :start_date, :end_date, presence: true
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :end_date_not_before_start_date
  validate :no_overlapping_invoice_for_membership
  validate :contiguous_with_membership_invoices, on: :create
  validate :only_one_upcoming_invoice
  validate :cost_cents_immutable_once_allocated, if: :will_save_change_to_cost_cents?
  validate :cost_dollars_is_valid

  def self.chargeable
    arel_table[:cost_cents].gt(0)
  end

  def self.cost_covered_by_allocations
    arel_table[:cost_cents].lteq(allocated_cents)
  end

  def self.allocated_cents
    allocations = Allocation.arel_table
    allocated = allocations.project(allocations[:amount].sum)
      .where(allocations[:allocatable_type].eq(polymorphic_name))
      .where(allocations[:allocatable_id].eq(arel_table[:id]))
    Arel::Nodes::NamedFunction.new("COALESCE", [ allocated, Arel.sql("0") ])
  end

  private_class_method :allocated_cents

  def active_on?(date = Date.current)
    return false if start_date.blank? || end_date.blank?

    (start_date..end_date).cover?(date)
  end

  def overdue?(as_of = Date.current)
    return false if paid_in_full? || start_date.blank?

    start_date <= as_of
  end

  def upcoming?(as_of = Date.current)
    start_date.present? && start_date > as_of
  end

  def cost_dollars
    cost_cents.to_d / 100 if cost_cents
  end

  def cost_dollars=(value)
    @cost_dollars_invalid = false
    return if value.blank?

    cents = MoneyParser.cents(value)
    if MoneyParser.invalid?(cents)
      @cost_dollars_invalid = true
    else
      self.cost_cents = cents
    end
  end

  def locked? = membership.locked?

  def pristine? = allocations.none?

  def payment_in_progress?
    return true if payment_in_progress_at.present? && payment_in_progress_at > 1.hour.ago

    charge_attempts.pending.where(attempted_at: 1.hour.ago..).exists?
  end

  def mark_payment_in_progress!
    update_columns(payment_in_progress_at: Time.current, checkout_session_id: nil)
  end

  def clear_payment_in_progress!
    return if payment_in_progress_at.nil? && checkout_session_id.nil?

    update_columns(payment_in_progress_at: nil, checkout_session_id: nil)
  end

  def latest_attempt = charge_attempts.last

  def attempts_exhausted?
    charge_attempts.where(status: "failed").count >= MembershipChargeAttempt::MAX_ATTEMPTS
  end

  attr_accessor :skip_deletion_guard

  def deletable?
    deletion_blocked_reason.nil?
  end

  def deletion_blocked_reason
    return "a payment is in progress" if payment_in_progress?
    return "it has payments or credits applied" unless allocations.sum(:amount).zero?
    return "it is the membership's only invoice" unless other_invoices?
    return "deleting it would leave a gap in the membership's invoices" if middle_invoice?
    return "it is the only invoice covering the membership term" unless term_still_covered?

    nil
  end

  def other_invoices?
    membership.membership_invoices.where.not(id: id).exists?
  end

  def receipt_available?
    paid_in_full? && payment_received?
  end

  def inherit_invoice_details
    return if membership.blank?

    previous = membership.membership_invoices.reorder(start_date: :desc, id: :desc).first
    return unless previous

    self.invoicee ||= previous.invoicee
    self.bill_to_address ||= previous.bill_to_address
    self.attention_person ||= previous.attention_person
    self.hide_invoicee = previous.hide_invoicee if hide_invoicee.nil?
    self.hide_address = previous.hide_address if hide_address.nil?
    self.bill_to_additional_info = previous.bill_to_additional_info if bill_to_additional_info.nil?
  end

  def bill_to_organization_id
    invoicee.id if invoicee.is_a?(Organization)
  end

  def bill_to_organization_id=(id)
    self.invoicee = id.present? ? Organization.find_by(id: id) : nil
  end

  def prevent_destroy_unless_deletable
    return if skip_deletion_guard || deletable?

    errors.add(:base, "Cannot delete this invoice because #{deletion_blocked_reason}.")
    throw :abort
  end

  def derive_end_date
    return if end_date.present? || start_date.blank?

    self.end_date = start_date + Membership::INVOICE_PERIOD - 1.day
  end

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "can't be before the start date")
  end

  def no_overlapping_invoice_for_membership
    return if start_date.blank? || end_date.blank? || membership.blank?

    overlapping = membership.membership_invoices
      .where(start_date: ..end_date, end_date: start_date..)
    overlapping = overlapping.where.not(id: id) if persisted?
    return unless overlapping.exists?

    errors.add(:base, "This membership already has an invoice overlapping #{start_date} to #{end_date}")
  end

  # One membership is one continuous coverage range. A new invoice may only
  # append after the last one or prepend before the first; a gap or an overlap
  # is rejected (the overlap validation gives the more specific message).
  def contiguous_with_membership_invoices
    return if start_date.blank? || end_date.blank? || membership.blank?

    others = membership.membership_invoices
    return unless others.exists?

    first_start = others.minimum(:start_date)
    last_end = others.maximum(:end_date)
    return if start_date == last_end + 1.day || end_date == first_start - 1.day

    errors.add(:base, "Invoices for a membership must be contiguous")
  end

  def only_one_upcoming_invoice
    return if start_date.blank? || membership_id.blank? || start_date <= Date.current

    upcoming = membership.membership_invoices.where("start_date > ?", Date.current)
    upcoming = upcoming.where.not(id: id) if persisted?
    return unless upcoming.exists?

    errors.add(:base, "This membership already has an upcoming invoice — remove next year before issuing another")
  end

  def cost_cents_immutable_once_allocated
    return if new_record?
    return if allocations.none?

    errors.add(:cost_cents, "can't change once a payment or discount is applied")
  end

  def cost_dollars_is_valid
    return unless @cost_dollars_invalid

    errors.add(:cost_dollars, "must be a number, e.g. 100 or 99.50")
  end

  private

  # Deleting a middle invoice would leave a hole between its neighbours.
  def middle_invoice?
    others = membership.membership_invoices.where.not(id: id)
    others.where("start_date < ?", start_date).exists? &&
      others.where("start_date > ?", start_date).exists?
  end

  # True while some remaining invoice still overlaps the membership term.
  def term_still_covered?
    others = membership.membership_invoices.where.not(id: id)
    first_start = others.minimum(:start_date)
    last_end = others.maximum(:end_date)
    return false if first_start.blank? || last_end.blank?

    [ membership.start_date, first_start ].compact.max <= [ membership.end_date, last_end ].compact.min
  end

  # After an invoice goes, shrink the term into what remains. Never extend:
  # a term that ended early stays short even when later invoices are removed.
  def clamp_membership_term
    return if membership.blank?

    remaining_start = membership.membership_invoices.minimum(:start_date)
    remaining_end = membership.membership_invoices.maximum(:end_date)
    return if remaining_start.blank? || remaining_end.blank?

    new_start = [ membership.start_date, remaining_start ].compact.max
    new_end = [ membership.end_date, remaining_end ].compact.min
    return if new_start.blank? || new_end.blank? || new_start > new_end
    return if new_start == membership.start_date && new_end == membership.end_date

    membership.update_columns(start_date: new_start, end_date: new_end)
  end

  def clear_payment_in_progress
    clear_payment_in_progress! if payment_in_progress_at.present? || checkout_session_id.present?
  end
end
