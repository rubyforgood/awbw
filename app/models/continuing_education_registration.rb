class ContinuingEducationRegistration < ApplicationRecord
  include Registerable

  has_paper_trail

  belongs_to :event_registration
  belongs_to :professional_license
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :allocations, as: :allocatable, dependent: :destroy
  has_many :payments, through: :allocations, source: :source, source_type: "Payment"

  before_validation :default_from_event, on: :create

  validates :hours, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :license_belongs_to_registrant

  # Payment interface (allocations_sum / paid_in_full? / remaining_cost / …) comes from
  # Registerable, driven by this record's own cost_cents column.

  # CE certificate eligibility — its own rule (not shared): the event grants CE,
  # the registrant attended, the training has ended, and the CE balance is paid.
  def certificate_available?
    event = event_registration&.event
    return false unless event&.ce_eligible?

    event.end_date&.past? && event_registration.attended? && paid_in_full?
  end

  private

  # Snapshot the hours offered and total cost from the event when they aren't set
  # explicitly.
  def default_from_event
    event = event_registration&.event
    self.hours = event.ce_hours_offered if event&.ce_hours_offered && (hours.blank? || hours.zero?)
    self.cost_cents = event.ce_hours_cost_cents if event&.ce_hours_cost_cents && (cost_cents.blank? || cost_cents.zero?)
  end

  def license_belongs_to_registrant
    return if professional_license.blank? || event_registration.blank?
    return if professional_license.person_id == event_registration.registrant_id

    errors.add(:professional_license, "must belong to the registrant")
  end
end
