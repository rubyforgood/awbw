class OrganizationPerson < ApplicationRecord
  belongs_to :organization
  belongs_to :person

  # Validations
  validates_presence_of :organization_id

  # Enum
  enum :position, { default: 0, liaison: 1, leader: 2, assistant: 3 }

  scope :active, -> {
    where(inactive: false)
      .where("end_date IS NULL OR end_date >= ?", Date.current)
  }

  before_save :set_inactive_from_dates
  after_save :deactivate_organization_if_no_active_people
  after_destroy :deactivate_organization_if_no_active_people

  # Methods
  def name
    "#{person.name}" if person
  end

  private

  def set_inactive_from_dates
    return unless end_date_changed? || start_date_changed?

    self.inactive = end_date.present? && end_date < Date.current
  end

  def deactivate_organization_if_no_active_people
    return if organization.organization_people.active.exists?

    inactive_status = OrganizationStatus.find_by(name: "Inactive")
    return unless inactive_status
    return if organization.organization_status_id == inactive_status.id

    organization.update!(organization_status: inactive_status)

    Ahoy::Tracker.new(user: Current.user).track(
      "autochange.organization",
      resource_type: "Organization",
      resource_id: organization.id,
      resource_title: organization.name,
      change: "status_set_to_inactive",
      reason: "no_active_organization_people"
    )
  end
end
