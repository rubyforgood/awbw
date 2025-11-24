class ProjectUser < ApplicationRecord
  belongs_to :project
  belongs_to :user

  # Validations
  validates_presence_of :project_id

  # Enum
  enum :position, { default: 0, liaison: 1, leader: 2, assistant: 3 }

  scope :active, -> { where(inactive: false) }

  # Methods
  def name
    "#{user.name}" if user
  end
end
