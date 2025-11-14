class ProjectUser < ApplicationRecord
  # Associations
  belongs_to :project
  belongs_to :user

  scope :active, -> { where(inactive: false) }
  scope :liaisons, -> { where(position: "liaison") }
  # Validations
  validates_presence_of :project_id

  # Enum
  enum :position, { default: 0, liaison: 1, leader: 2, assistant: 3 }

  # Methods
  def name
    "#{user.name}" if user
  end
end
