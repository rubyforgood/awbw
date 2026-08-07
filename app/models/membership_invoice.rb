class MembershipInvoice < ApplicationRecord
  include Registerable

  has_paper_trail

  belongs_to :membership
  has_many :allocations, as: :allocatable, dependent: :destroy
  has_many :payments, through: :allocations, source: :source, source_type: "Payment"

  delegate :person, to: :membership
  alias_method :registrant, :person

  scope :active_on, ->(date = Date.current) { where(start_date: ..date, end_date: date..) }
  scope :expiring_between, ->(from, to) { where(end_date: from..to) }

  scope :paid_in_full, -> { where(cost_covered_by_allocations) }
  scope :not_paid_in_full, -> { where(chargeable.and(cost_covered_by_allocations.not)) }
  scope :overdue, ->(as_of = Date.current) {
    not_paid_in_full.where(start_date: ...(as_of - Membership::GRACE_PERIOD_DAYS))
  }
  # Defined as the complement to `overdue` so it can't drift.
  scope :paid_or_within_grace, ->(as_of = Date.current) {
    where.not(id: MembershipInvoice.overdue(as_of))
  }

  before_validation :derive_end_date, on: :create

  validates :start_date, :end_date, presence: true
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :end_date_not_before_start_date
  validate :no_overlapping_invoice_for_person
  validate :cost_not_below_allocations, on: :update

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

    as_of > start_date + Membership::GRACE_PERIOD_DAYS
  end

  def within_grace?(as_of = Date.current)
    return false if paid_in_full?

    !overdue?(as_of)
  end

  def cost_dollars
    cost_cents.to_d / 100 if cost_cents
  end

  def cost_dollars=(value)
    self.cost_cents = (value.to_d * 100).to_i if value.present?
  end

  private

  def derive_end_date
    return if end_date.present? || start_date.blank?

    self.end_date = start_date + Membership::INVOICE_PERIOD - 1.day
  end

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "can't be before the start date")
  end

  # Spans every membership the person has, not just this one: a cancelled
  # subscription keeps its coverage to the invoice's end, so a rejoin can otherwise
  # produce two subscriptions covering the same day.
  def no_overlapping_invoice_for_person
    return if start_date.blank? || end_date.blank? || membership&.person.blank?

    overlapping = membership.person.membership_invoices
      .where(start_date: ..end_date, end_date: start_date..)
    overlapping = overlapping.where.not(id: id) if persisted?
    return unless overlapping.exists?

    errors.add(:base, "This person already has a membership invoice overlapping #{start_date} to #{end_date}")
  end

  def cost_not_below_allocations
    return if cost_cents.blank?
    return if cost_cents.to_i >= allocations_sum

    errors.add(:cost_cents,
      "can't be less than the amount already allocated (#{MoneyFormatter.dollars_from_cents(allocations_sum)})")
  end
end
