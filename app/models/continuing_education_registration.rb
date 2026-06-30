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

  # Display a CE hours figure without trailing zeros: "6", "1.5".
  def self.format_hours(hours)
    return if hours.blank?

    number = hours.to_f
    number == number.to_i ? number.to_i.to_s : number.to_s
  end

  # CE certificate eligibility — its own rule (not shared): the event grants CE,
  # the registrant attended, the training has ended, and the CE balance is paid.
  def certificate_available?
    event = event_registration&.event
    return false unless event&.ce_eligible?

    event.end_date&.past? && event_registration.attended? && paid_in_full?
  end

  # Point this registration at the registrant's license for the typed type +
  # number, editing the current license in place — filling a blank placeholder and
  # fixing a typo both just correct this one record (and its PaperTrail history).
  # The exception: if the typed number already belongs to another license this
  # person holds, link to that one rather than duplicating or colliding on the
  # unique (person, number) index. Does not save the registration itself — callers
  # persist it alongside their other changes.
  def assign_license(number:, kind:, issuing_state: nil, expires_on: nil)
    number = number.to_s.strip.presence
    kind = kind.to_s.strip.presence
    issuing_state = issuing_state.to_s.strip.presence
    expires_on = expires_on.presence
    current = professional_license
    person = event_registration.registrant

    match = person.professional_licenses.where.not(id: current.id).find_by(number: number) if number
    if match
      self.professional_license = match
    else
      current.update!(number: number, kind: kind, issuing_state: issuing_state, expires_on: expires_on)
    end
  end

  # Human-readable payment status, mirroring EventRegistration#payment_status_label.
  # CE has no "intends to pay" concept (that's an event-access affordance), so the
  # middle state is a genuine partial payment instead.
  def payment_status_label
    return "Paid" if paid_in_full?
    return "Partial" if partially_paid?
    "Due"
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
