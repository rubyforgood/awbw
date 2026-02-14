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

  # Methods
  def name
    "#{person.name}" if person
  end

  private

  def set_inactive_from_dates
    return unless end_date_changed? || start_date_changed?

    self.inactive = end_date.present? && end_date < Date.current
  end
end
