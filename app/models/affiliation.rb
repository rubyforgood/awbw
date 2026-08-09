class Affiliation < ApplicationRecord
  # Standing title given to the "facilitator affiliation" we create on registration
  # and org linking. Matches the `facilitators` scope / `facilitator?` predicate
  # (both treat exactly "Facilitator" as canonical).
  FACILITATOR_TITLE = "Facilitator".freeze

  # Status taxonomy shown/filtered on the attendees index, in display order.
  STATUSES = %w[ Active Pending Inactive ].freeze

  belongs_to :organization, inverse_of: :affiliations
  belongs_to :person, touch: true
  # Which of the organization's addresses this person is affiliated with (optional).
  belongs_to :organization_address, class_name: "Address", optional: true

  # Validations
  validates_presence_of :organization_id
  validate :organization_address_belongs_to_organization

  # Not flagged inactive and not past its end date. Includes affiliations whose
  # start_date is still in the future (e.g. a Facilitator affiliation dated to an
  # upcoming training's month) — they are "pending" but counted here.
  scope :active_or_pending, -> {
    where(inactive: false)
      .where("affiliations.end_date IS NULL OR affiliations.end_date >= ?", Date.current)
  }

  scope :active, -> { active_or_pending }

  # Affiliations that overlapped a given date, judged purely by their start/end
  # dates rather than the cached `inactive` flag (which reflects "now"). Use this
  # when a view must reflect a fixed point in time — e.g. the event dashboard
  # reporting organizations as they stood at the time of the event, so the
  # numbers don't drift as affiliations end after the fact.
  scope :active_on, ->(date) {
    where("affiliations.start_date IS NULL OR affiliations.start_date <= ?", date)
      .where("affiliations.end_date IS NULL OR affiliations.end_date >= ?", date)
  }

  # Only the exact, case-sensitive title "Facilitator" counts — variants like
  # "Lead Facilitator" or "facilitator" are deliberately excluded. BINARY forces
  # a case-sensitive comparison under MySQL's default case-insensitive collation;
  # TRIM mirrors the in-memory #facilitator? strip so stray whitespace still matches.
  scope :facilitators, -> { where("BINARY TRIM(title) = ?", "Facilitator") }

  # Affiliations whose #status_on(date) equals the given status, expressed in SQL
  # so it composes as a subquery (e.g. person-id narrowing). Kept in lock-step with
  # #status_on by an executable agreement spec.
  scope :with_status, ->(status, on: Date.current) {
    case status
    when "Active"
      where(inactive: false)
        .where("affiliations.start_date IS NULL OR affiliations.start_date <= ?", on)
        .where("affiliations.end_date IS NULL OR affiliations.end_date >= ?", on)
    when "Pending"
      where(inactive: false).where("affiliations.start_date > ?", on)
    when "Inactive"
      where("affiliations.inactive = ? OR affiliations.end_date < ?", true, on)
    else
      none
    end
  }

  before_validation :skip_if_duplicate
  before_save :set_inactive_from_dates
  after_save :sync_organization_status_with_affiliations
  after_save :sync_organization_affiliation_dates
  after_destroy :sync_organization_status_with_affiliations
  after_destroy :sync_organization_affiliation_dates

  # Methods
  # A facilitator affiliation is one whose title is *exactly* "Facilitator"
  # (trimmed, case-sensitive). Variants like "Lead Facilitator" or "facilitator"
  # are deliberately excluded. Mirrors the .facilitators scope so in-memory and
  # SQL checks agree.
  def facilitator?
    title.to_s.strip == "Facilitator"
  end

  # Current: not flagged inactive and not past its end date. Mirrors the `active`
  # scope so already-loaded affiliations can be filtered in Ruby without another
  # query (e.g. on list pages that preload affiliations).
  def active?
    !inactive? && (end_date.nil? || end_date >= Date.current)
  end

  # This affiliation's status as of a date: Inactive (flagged or ended), Pending
  # (future start), otherwise Active. The in-memory twin of the .with_status scope.
  def status_on(date = Date.current)
    return "Inactive" if inactive? || (end_date && end_date < date)
    return "Pending" if start_date && start_date > date
    "Active"
  end

  def name
    "#{person.name}" if person
  end

  private

  # The linked address must be one of this affiliation's organization's own
  # addresses — not a stray address or another org's / person's address.
  def organization_address_belongs_to_organization
    return if organization_address.blank?

    valid = organization_address.addressable_type == "Organization" &&
            organization_address.addressable_id == organization_id
    errors.add(:organization_address_id, "must be an address of this organization") unless valid
  end

  def skip_if_duplicate
    scope = Affiliation.where(
      organization_id: organization_id,
      person_id: person_id,
      start_date: start_date,
      end_date: end_date,
      inactive: inactive,
      title: title&.strip
    )
    scope = scope.where.not(id: id) if persisted?

    throw(:abort) if scope.exists?
  end

  def set_inactive_from_dates
    return unless end_date_changed? || start_date_changed?

    self.inactive = end_date.present? && end_date < Date.current
  end

  def sync_organization_affiliation_dates
    org = organization
    affiliations = org.affiliations.where.not(id: destroyed_by_association ? id : nil)

    earliest_start = affiliations.minimum(:start_date)
    has_active = affiliations.active.exists?

    updates = {}
    updates[:start_date] = earliest_start if org.start_date != earliest_start
    if has_active
      updates[:end_date] = nil if org.end_date.present?
    else
      latest_end = affiliations.maximum(:end_date)
      updates[:end_date] = latest_end if org.end_date != latest_end
    end

    org.update_columns(updates) if updates.any?
  end

  # Org status tracks active *Facilitator* affiliations specifically (mirroring the
  # form's status indicator) — a non-facilitator affiliation does not keep an org active.
  def sync_organization_status_with_affiliations
    if organization.affiliations.facilitators.active.exists?
      reactivate_organization_if_inactive
    else
      deactivate_organization_if_no_active_people
    end
  end

  def deactivate_organization_if_no_active_people
    inactive_status = OrganizationStatus.find_by(name: "Inactive")
    return unless inactive_status
    return if organization.organization_status_id == inactive_status.id

    organization.update_column(:organization_status_id, inactive_status.id)

    Ahoy::Tracker.new(user: Current.user).track(
      "autochange.organization",
      resource_type: "Organization",
      resource_id: organization.id,
      resource_title: organization.name,
      change: "status_set_to_inactive",
      reason: "no_active_affiliations"
    )
  end

  # Only flip back from "Inactive" — the status the deactivation callback sets.
  # Leave Pending/Reinstate/Unknown (and Active) untouched.
  def reactivate_organization_if_inactive
    inactive_status = OrganizationStatus.find_by(name: "Inactive")
    active_status = OrganizationStatus.find_by(name: "Active")
    return unless inactive_status && active_status
    return unless organization.organization_status_id == inactive_status.id

    organization.update_column(:organization_status_id, active_status.id)

    Ahoy::Tracker.new(user: Current.user).track(
      "autochange.organization",
      resource_type: "Organization",
      resource_id: organization.id,
      resource_title: organization.name,
      change: "status_set_to_active",
      reason: "regained_active_affiliation"
    )
  end
end
