class Affiliation < ApplicationRecord
  belongs_to :organization
  belongs_to :person, touch: true

  # Validations
  validates_presence_of :organization_id
  validates_presence_of :person_id

  # Enum
  enum :position, { default: 0, liaison: 1, leader: 2, assistant: 3 }

  scope :active, -> {
    where(inactive: false)
      .where("end_date IS NULL OR end_date >= ?", Date.current)
  }

  before_validation :skip_if_duplicate
  before_save :set_inactive_from_dates
  after_save :deactivate_organization_if_no_active_people
  after_save :sync_organization_affiliation_dates
  after_destroy :deactivate_organization_if_no_active_people
  after_destroy :sync_organization_affiliation_dates

  # Methods
  def name
    "#{person.name}" if person
  end

  private

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

  def deactivate_organization_if_no_active_people
    return if organization.affiliations.active.exists?

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
end
