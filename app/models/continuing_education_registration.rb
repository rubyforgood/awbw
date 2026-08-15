class ContinuingEducationRegistration < ApplicationRecord
  include Registerable
  include Certifiable

  # AWBW's continuing-education accreditation, referenced by the CE callout copy
  # and the completion certificate's CE clause. Kept here as the single source of
  # truth so the certificate and any callout text point at the same body + link.
  ACCREDITATION_BODY = "the California Association of Marriage and Family Therapists (CAMFT)".freeze
  ACCREDITATION_URL = "https://www.camft.org/".freeze
  # AWBW's CAMFT approved-provider number (per awbw.org's CE hours page).
  ACCREDITATION_PROVIDER_NUMBER = "1000151".freeze

  has_paper_trail

  belongs_to :event_registration
  delegate :registrant, to: :event_registration
  belongs_to :professional_license
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :allocations, as: :allocatable, dependent: :destroy
  has_many :payments, through: :allocations, source: :source, source_type: "Payment"
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy

  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }

  # Virtual sub-fields for the edit form's license inputs. The controller reads
  # them from params and routes them through #assign_license; declared here so the
  # form builder can bind to them (SimpleForm reads the object when a field's
  # value is nil, e.g. a blank expiry on a placeholder license).
  attr_accessor :license_kind, :license_number, :license_issuing_state, :license_expires_on

  before_validation :default_from_event, on: :create

  validates :hours, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :license_belongs_to_registrant
  validate :cost_not_below_allocations, on: :update

  scope :for_event, ->(event_id) { joins(:event_registration).where(event_registrations: { event_id: event_id }) }
  scope :for_registrant, ->(person_id) { joins(:event_registration).where(event_registrations: { registrant_id: person_id }) }
  scope :certificate_issued, -> { where.not(certificate_sent_at: nil) }
  scope :certificate_pending, -> { where(certificate_sent_at: nil) }

  # Drives the admin index filters (event, registrant, certificate status).
  def self.search_by_params(params)
    results = all
    results = results.for_event(params[:event_id]) if params[:event_id].present?
    results = results.for_registrant(params[:person_id]) if params[:person_id].present?
    results = results.certificate_issued if params[:certificate] == "issued"
    results = results.certificate_pending if params[:certificate] == "pending"
    results
  end

  # Payment interface (allocations_sum / paid_in_full? / remaining_cost / …) comes from
  # Registerable, driven by this record's own cost_cents column.

  # The logged sign-in time must cover at least this fraction of the awarded CE
  # contact hours before the certificate unlocks — a little slack for slightly-late
  # sign-ins/early sign-outs. You can't certify hours the sign-in sheet doesn't support.
  ATTENDANCE_COVERAGE_THRESHOLD = 0.9

  # CE certificate eligibility — its own rule (not shared): the event grants CE,
  # the registrant attended, the training has ended, the CE balance is paid, and
  # (when attendance was tracked) the logged time approximately covers the hours.
  def certificate_available?
    event = event_registration&.event
    return false unless event&.ce_eligible?
    return false unless event.end_date&.past? && event_registration.attended? && paid_in_full?

    attendance_time_sufficient?
  end

  # When attendance time has been logged for this registrant, it must approximately
  # cover the awarded hours before the certificate unlocks. With nothing logged (the
  # portal sign-in wasn't used for this event), day-level attendance alone governs,
  # so this doesn't block — it never retroactively gates events that never tracked time.
  def attendance_time_sufficient?
    logged = event_registration.attendance_minutes_total
    return true if logged.zero?

    logged >= required_attendance_minutes
  end

  # Minutes of logged attendance needed to certify the awarded hours (with tolerance).
  def required_attendance_minutes
    (hours.to_d * 60 * ATTENDANCE_COVERAGE_THRESHOLD).round
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
