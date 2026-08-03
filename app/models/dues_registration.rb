class DuesRegistration < ApplicationRecord
  include Registerable

  has_paper_trail

  belongs_to :dues_membership
  has_many :allocations, as: :allocatable, dependent: :destroy
  has_many :payments, through: :allocations, source: :source, source_type: "Payment"

  delegate :person, to: :dues_membership

  validates :start_date, :end_date, presence: true
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :end_date_not_before_start_date
  validate :no_overlapping_term_for_person
  validate :cost_not_below_allocations, on: :update

  private

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "can't be before the start date")
  end

  # Spans every membership the person has, not just this one: a cancelled
  # membership keeps its coverage to the term's end, so a rejoin can otherwise
  # produce two memberships covering the same day.
  def no_overlapping_term_for_person
    return if start_date.blank? || end_date.blank? || dues_membership&.person.blank?

    overlapping = dues_membership.person.dues_registrations
      .where(start_date: ..end_date, end_date: start_date..)
    overlapping = overlapping.where.not(id: id) if persisted?
    return unless overlapping.exists?

    errors.add(:base, "This person already has a dues year overlapping #{start_date} to #{end_date}")
  end

  def cost_not_below_allocations
    return if cost_cents.blank?
    return if cost_cents.to_i >= allocations_sum

    errors.add(:cost_cents,
      "can't be less than the amount already allocated (#{MoneyFormatter.dollars_from_cents(allocations_sum)})")
  end
end
