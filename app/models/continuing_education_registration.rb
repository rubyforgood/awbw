class ContinuingEducationRegistration < ApplicationRecord
  include Registerable
  include Certifiable
  include Communicable

  has_paper_trail

  belongs_to :event_registration
  delegate :registrant, to: :event_registration
  belongs_to :professional_license
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :allocations, as: :allocatable, dependent: :destroy
  has_many :payments, through: :allocations, source: :source, source_type: "Payment"
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy

  def communications_email
    registrant&.preferred_email
  end

  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }

  # Virtual sub-fields for the edit form's license inputs. The controller reads
  # them from params and routes them through #assign_license; declared here so the
  # form builder can bind to them (SimpleForm reads the object when a field's
  # value is nil, e.g. a blank expiry on a placeholder license).
  attr_accessor :license_kind, :license_number, :license_issuing_state, :license_issuing_state_outside_usa,
                :license_issuing_country, :license_expires_on

  # Set when the transfer flow creates the destination record with a deliberately
  # snapshotted hours/cost (including a $0 cost), so #default_from_event doesn't
  # overwrite them with the event's offering. (#1944)
  attr_accessor :skip_event_defaults

  before_validation :default_from_event, on: :create

  validates :hours, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :license_belongs_to_registrant
  # Create-only: merges move CE rows across first and fold the duplicates afterward.
  validates :professional_license, uniqueness: { scope: :event_registration_id, message: "already has CE on this registration" }, on: :create
  validate :cost_not_below_allocations, on: :update

  scope :for_event, ->(event_id) { joins(:event_registration).where(event_registrations: { event_id: event_id }) }
  scope :for_registrant, ->(person_id) { joins(:event_registration).where(event_registrations: { registrant_id: person_id }) }
  scope :for_license, ->(license_id) { where(professional_license_id: license_id) }
  scope :certificate_issued, -> { where.not(certificate_sent_at: nil) }
  scope :certificate_pending, -> { where(certificate_sent_at: nil) }
  scope :issued_on_or_after, ->(date) { where(certificate_sent_at: date.beginning_of_day..) }
  scope :issued_on_or_before, ->(date) { where(certificate_sent_at: ..date.end_of_day) }

  # Drives the admin index filters (event, registrant, license, certificate
  # status, and issued-date range).
  def self.search_by_params(params)
    results = all
    results = results.for_event(params[:event_id]) if params[:event_id].present?
    results = results.for_registrant(params[:person_id]) if params[:person_id].present?
    results = results.for_license(params[:professional_license_id]) if params[:professional_license_id].present?
    results = results.certificate_issued if params[:certificate] == "issued"
    results = results.certificate_pending if params[:certificate] == "pending"
    if (from = parse_iso_date(params[:issued_from]))
      results = results.issued_on_or_after(from)
    end
    if (to = parse_iso_date(params[:issued_to]))
      results = results.issued_on_or_before(to)
    end
    results
  end

  # Enrolls a registration in CE against the registrant's license for the given
  # number and kind (a placeholder license when none was given); hours and cost come
  # from the event. A registration that already has CE keeps that one record, with
  # its license updated from these values. A license is matched by number + kind, so
  # it may already carry a state and expiry from an earlier event — only the values
  # given here are written, since a blank one means "not supplied", never "clear
  # what's on file".
  def self.enroll!(event_registration:, number: nil, kind: nil, issuing_state: nil, issuing_country: nil, expires_on: nil)
    transaction do
      # Serializes a double-submit; the locking read sees a CE the other request just committed.
      EventRegistration.lock.find(event_registration.id)
      existing = event_registration.continuing_education_registrations.lock.first
      next existing.tap { |ce| ce.refresh_license!(number:, kind:, issuing_state:, issuing_country:, expires_on:) } if existing

      license = ProfessionalLicense.find_or_create_for(person: event_registration.registrant, number: number, kind: kind)
      attributes = { issuing_state: issuing_state, issuing_country: issuing_country, expires_on: expires_on }.compact
      license.update!(attributes) if attributes.any?
      event_registration.continuing_education_registrations.create!(professional_license: license)
    end
  end

  def self.parse_iso_date(value)
    return if value.blank?
    parts = Date._parse(value.to_s)
    Date.new(parts[:year], parts[:mon], parts[:mday]) if parts[:year] && parts[:mon] && parts[:mday]
  end

  # Payment interface (allocations_sum / paid_in_full? / remaining_cost / …) comes from
  # Registerable, driven by this record's own cost_cents column.

  # The logged sign-in time must cover at least this fraction of the awarded CE
  # contact hours before the certificate unlocks — a little slack for slightly-late
  # sign-ins/early sign-outs. You can't certify hours the sign-in sheet doesn't support.
  ATTENDANCE_COVERAGE_THRESHOLD = 0.9

  # This record was created by a transfer — carried onto a transferred-in reg from
  # a matching CE the split left on the source. Identified by that source stub
  # existing (matched by license), NOT merely by the reg being a transfer-in: a CE
  # an admin adds fresh at the new event has no source stub, so it stays a normal,
  # editable record. Cost is admin-locked only for the transfer-carried record;
  # certification happens at this event. (#1944)
  def transfer_created?
    origin_ce_registration.present?
  end

  # The source reg's CE record this one was split from — the paid $0-hours "stub"
  # left at the original event, matched by license. Drives the "paid on original →"
  # link on a transfer-carried record's card. Nil when the source has no matching
  # CE (i.e. this was added fresh here, not carried by the transfer). (#1944)
  def origin_ce_registration
    return unless event_registration&.transferred_in?

    event_registration.transferred_from_registration
      &.continuing_education_registrations
      &.find { |c| c.professional_license_id == professional_license_id }
  end

  # CE certificate eligibility — its own rule (not shared): the event grants CE,
  # the registrant attended, the training has ended, the CE balance is paid, the
  # CE callout's post-training form (if one is set) is complete, and (when
  # attendance was tracked) the logged time approximately covers the hours.
  # Everything is judged at this record's own event/registration — after a transfer
  # the hours ride on the destination reg's own record, so there's nothing to walk.
  def certificate_available?
    event = event_registration&.event
    return false unless event&.ce_eligible?
    return false unless event.end_date&.past? && event_registration.attended? && paid_in_full?
    return false unless event_registration.ce_form_requirement_met?

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
  def assign_license(number:, kind:, issuing_state: nil, issuing_country: nil, expires_on: nil, license_id: nil)
    number = number.to_s.strip.presence
    kind = kind.to_s.strip.presence
    issuing_state = issuing_state.to_s.strip.presence
    issuing_country = issuing_country.presence
    expires_on = expires_on.presence
    current = professional_license
    person = event_registration.registrant

    if license_id.present? && license_id != "new"
      picked = person.professional_licenses.find_by(id: license_id)
      if picked
        picked.update!(number: number, kind: kind, issuing_state: issuing_state, issuing_country: issuing_country, expires_on: expires_on)
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
      target.update!(number: number, kind: kind, issuing_state: issuing_state, issuing_country: issuing_country, expires_on: expires_on)
      self.professional_license = target
    end
  end

  # A reapplication's license answers, each blank one keeping what's on file. An
  # issued certificate's license stays the credential it was issued under.
  def refresh_license!(number: nil, kind: nil, issuing_state: nil, issuing_country: nil, expires_on: nil)
    return if certificate_sent_at.present?

    kind, number = ProfessionalLicense.split_kind_from_number(kind:, number:)
    # Locking read: a double-submit's other request may have just created this license.
    license = self.professional_license = ProfessionalLicense.lock.find(professional_license_id)
    details = { issuing_state:, issuing_country:, expires_on: }.compact_blank
    if number.present? && number != license.number && license_used_by_other_ce?
      # Another event's CE keeps the license it was given, so the new number gets its own.
      self.professional_license = ProfessionalLicense.find_or_create_for(person: registrant, number:, kind: kind.presence || license.kind)
    else
      assign_license(number: number.presence || license.number, kind: kind.presence || license.kind,
                     issuing_state: license.issuing_state, issuing_country: license.issuing_country,
                     expires_on: license.expires_on)
    end
    professional_license.update!(details) if details.any?
    save! if changed?
  end

  # May this CE reach CE-paid content (callouts gated on CE payment)? Mirrors
  # EventRegistration#payment_access_granted?; reporting keeps using paid_in_full?.
  def payment_access_granted?
    paid_in_full? || intends_to_pay?
  end

  # Human-readable payment status — the real balance, so intending to pay still reads Due.
  def payment_status_label
    return "Paid" if paid_in_full?
    return "Partial" if partially_paid?
    "Due"
  end

  private

  # Snapshot the hours offered and total cost from the event when they aren't set
  # explicitly. Skipped for a transfer-created record, whose hours/cost are
  # deliberately carried over from the source (a $0 cost is intentional there).
  def default_from_event
    return if skip_event_defaults

    event = event_registration&.event
    self.hours = event.ce_hours_offered if event&.ce_hours_offered && (hours.blank? || hours.zero?)
    self.cost_cents = event.ce_hours_cost_cents if event&.ce_hours_cost_cents && (cost_cents.blank? || cost_cents.zero?)
  end

  def license_used_by_other_ce?
    self.class.where(professional_license_id:).where.not(id:).exists?
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
