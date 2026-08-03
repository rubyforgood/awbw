class ContinuingEducationRegistration < ApplicationRecord
  include Registerable
  include Certifiable

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
  validate :cost_not_below_allocations, on: :update

  # Payment interface (allocations_sum / paid_in_full? / remaining_cost / …) comes from
  # Registerable, driven by this record's own cost_cents column.

  # CE certificate eligibility — its own rule (not shared): the event grants CE,
  # the registrant attended, the training has ended, and the CE balance is paid.
  def certificate_available?
    event = event_registration&.event
    return false unless event&.ce_eligible?

    event.end_date&.past? && event_registration.attended? && paid_in_full?
  end

  # Point this registration at a license for the typed type + number. `license_id`
  # comes from the form's license picker (shown when the registrant holds licenses):
  #   * an existing license → correct it in place from the typed fields (the picker
  #     populates those fields from whichever license is selected, so editing one
  #     and saving updates that license);
  #   * "new" → create a brand-new license for the person from the typed fields;
  #   * blank (no picker) → correct the current license in place (filling a blank
  #     placeholder or fixing a typo).
  # In the "new"/"blank" cases an existing license already holding the typed number
  # wins, to avoid duplicating or colliding on the unique (person, number) index.
  # Does not save the registration itself — callers persist it alongside their other
  # changes.
  def assign_license(number:, kind:, issuing_state: nil, expires_on: nil, license_id: nil)
    number = number.to_s.strip.presence
    kind = kind.to_s.strip.presence
    issuing_state = issuing_state.to_s.strip.presence
    expires_on = expires_on.presence
    current = professional_license
    person = event_registration.registrant

    if license_id.present? && license_id != "new"
      picked = person.professional_licenses.find_by(id: license_id)
      if picked
        picked.update!(number: number, kind: kind, issuing_state: issuing_state, expires_on: expires_on)
        self.professional_license = picked
        return
      end
    end

    # Licenses are identified by (kind, number), so only an exact kind + number
    # match is a duplicate to link to rather than create.
    match = person.professional_licenses.where.not(id: current&.id).find_by(number: number, kind: kind) if number
    if match
      self.professional_license = match
    else
      target = license_id == "new" ? person.professional_licenses.new : current
      target.update!(number: number, kind: kind, issuing_state: issuing_state, expires_on: expires_on)
      self.professional_license = target
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

  def cost_not_below_allocations
    return if cost_cents.blank?
    return if cost_cents.to_i >= allocations_sum

    errors.add(:cost_cents, "can't be less than the amount already allocated (#{MoneyFormatter.dollars_from_cents(allocations_sum)})")
  end
end
