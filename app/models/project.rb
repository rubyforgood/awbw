class Project < ApplicationRecord
  # Associations
  belongs_to :location
  belongs_to :windows_type
  has_many :project_users
  has_many :users, through: :project_users
  has_many :reports, through: :users
  has_many :workshop_logs, through: :users
  belongs_to :project_status

  # Methods
  def led_by?(user)
    return false unless leader
    leader.user == user
  end

  def log_title
    "#{name} #{windows_type.log_label if windows_type}"
  end

  private

  def leader
    project_users.find_by(position: 2)
  end
end
