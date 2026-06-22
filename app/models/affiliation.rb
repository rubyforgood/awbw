class Affiliation < ApplicationRecord
  # Standing title given to the "facilitator affiliation" we create on registration
  # and org linking. Matches the `facilitators` scope / `facilitator?` predicate
  # (both treat exactly "Facilitator" as canonical).
  FACILITATOR_TITLE = "Facilitator".freeze

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

  # Currently active: active-or-pending AND its start_date has arrived (or is
  # unset). A future-dated affiliation (e.g. a Facilitator dated to an upcoming
  # training's month) is therefore "pending" — counted by active_or_pending but
  # not yet active.
  scope :active, -> {
    active_or_pending
      .where("affiliations.start_date IS NULL OR affiliations.start_date <= ?", Date.current)
  }

  # Only the exact, case-sensitive title "Facilitator" counts — variants like
  # "Lead Facilitator" or "facilitator" are deliberately excluded. BINARY forces
  # a case-sensitive comparison under MySQL's default case-insensitive collation;
  # TRIM mirrors the in-memory #facilitator? strip so stray whitespace still matches.
  scope :facilitators, -> { where("BINARY TRIM(title) = ?", "Facilitator") }

  before_validation :skip_if_duplicate
  before_save :set_inactive_from_dates
  after_save :sync_organization_status_from_affiliations
  after_save :sync_organization_affiliation_dates
  after_destroy :sync_organization_status_from_affiliations
  after_destroy :sync_organization_affiliation_dates

  # Methods
  # A facilitator affiliation is one whose title is *exactly* "Facilitator"
  # (trimmed, case-sensitive). Variants like "Lead Facilitator" or "facilitator"
  # are deliberately excluded. Mirrors the .facilitators scope so in-memory and
  # SQL checks agree.
  def facilitator?
    title.to_s.strip == "Facilitator"
  end

  # Active-or-pending: not flagged inactive and not past its end date. A future
  # start_date still counts (the affiliation is pending, not ended). Mirrors the
  # `active_or_pending` scope for in-memory filtering of preloaded affiliations.
  def active_or_pending?
    !inactive? && (end_date.nil? || end_date >= Date.current)
  end

  # Currently active: active-or-pending AND its start_date has arrived. Mirrors
  # the `active` scope so already-loaded affiliations can be filtered in Ruby
  # without another query (e.g. on list pages that preload affiliations).
  def active?
    active_or_pending? && (start_date.nil? || start_date <= Date.current)
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
    has_active = affiliations.active_or_pending.exists?

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

  # Keep the organization's Active/Inactive status in sync with whether it has any
  # active-or-pending affiliations (an incoming facilitator counts). Symmetric:
  # activates an Inactive org that gains people and deactivates one that loses
  # them. Only ever toggles between Active and Inactive — manual states (Pending,
  # Reinstate, Suspended, Unknown) are left untouched so they stick.
  def sync_organization_status_from_affiliations
    has_people = organization.affiliations.active_or_pending.exists?
    current_name = organization.organization_status&.name
    target_name = has_people ? "Active" : "Inactive"

    return if current_name == target_name
    return unless [ "Active", "Inactive", nil ].include?(current_name)

    target_status = OrganizationStatus.find_by(name: target_name)
    return unless target_status

    organization.update_column(:organization_status_id, target_status.id)

    Ahoy::Tracker.new(user: Current.user).track(
      "autochange.organization",
      resource_type: "Organization",
      resource_id: organization.id,
      resource_title: organization.name,
      change: has_people ? "status_set_to_active" : "status_set_to_inactive",
      reason: has_people ? "active_affiliation_present" : "no_active_affiliations"
    )
  end
end
