class ProjectUser < ApplicationRecord
  # Associations
  belongs_to :project
  belongs_to :user

  scope :liaisons, -> { where(position: 1) }
  # Validations
  validates_presence_of :project_id

  # Enum
  enum position: [:default, :liaison, :leader, :assistant]
  # Rails admin
  rails_admin do
    exclude_fields :agency_id, :position
  end

  # Methods
  def name
    "#{user.name}" if user
  end
end
