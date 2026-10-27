class MembershipInvoice < ApplicationRecord
  include PersonNameSearchable, Registerable

  has_paper_trail

  belongs_to :membership
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :allocations, as: :allocatable, dependent: :destroy

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

  before_validation :derive_end_date, on: :create
  before_validation :inherit_invoice_details, on: :create
  before_destroy :prevent_destroy_unless_deletable
  after_save :sync_membership_dates, if: :paid_in_full?
  after_commit :enqueue_subscription_price_sync, on: :create, if: :next_billing_year?

  validates :start_date, :end_date, presence: true
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :end_date_not_before_start_date
  validate :no_overlapping_invoice_for_person
  validate :only_one_upcoming_invoice

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
    self.cost_cents = (value.to_d * 100).to_i if value.present?
  end

  attr_accessor :skip_deletion_guard

  def deletable?
    deletion_blocked_reason.nil?
  end

  def deletion_blocked_reason
    return "it has payments or credits applied" if allocations.exists?
    return "it is comped" if cost_cents.to_i.zero? && !upcoming?
    return "it covers today — click Cancel recurring first" if active_on?(Date.current) && !membership.autorenewal_cancelled?
    return "it is the membership's only invoice" unless other_invoices?

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

  def no_overlapping_invoice_for_person
    return if start_date.blank? || end_date.blank? || membership&.person.blank?

    overlapping = membership.person.membership_invoices
      .where(start_date: ..end_date, end_date: start_date..)
    overlapping = overlapping.where.not(id: id) if persisted?
    return unless overlapping.exists?

    errors.add(:base, "This person already has a membership invoice overlapping #{start_date} to #{end_date}")
  end

  def only_one_upcoming_invoice
    return if start_date.blank? || membership_id.blank? || start_date <= Date.current

    upcoming = membership.membership_invoices.where("start_date > ?", Date.current)
    upcoming = upcoming.where.not(id: id) if persisted?
    return unless upcoming.exists?

    errors.add(:base, "This membership already has an upcoming invoice — delete it before adding another")
  end

  private

  def next_billing_year?
    Membership.enabled? && start_date.present? && start_date > Date.current
  end

  def enqueue_subscription_price_sync
    SyncMembershipSubscriptionPriceJob.perform_later(membership_id)
  end

  def sync_membership_dates
    membership.sync_dates_from_invoice(self)
  end
end
