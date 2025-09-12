class Project < ApplicationRecord
  # Associations
  belongs_to :location
  belongs_to :windows_type
  has_many :project_users
  has_many :users, through: :project_users
  has_many :reports, through: :users
  has_many :workshop_logs, through: :users
  belongs_to :project_status

  # Rails Admin
  rails_admin do
    list do
      exclude_fields :windows_type
    end
    edit do
      exclude_fields :users, :project_users, :reports, :workshop_logs, :windows_type
      group 'More Fields' do
        active false
        field :location
        field :district
        field :start_date
        field :end_date
        field :locality
        field :description
        field :notes
        field :legacy
      end
    end
  end

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
