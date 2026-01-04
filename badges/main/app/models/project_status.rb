class ProjectStatus < ApplicationRecord
  PROJECT_STATUSES = [ "Active", "Inactive", "Pending", "Reinstate", "Suspended", "Unknown" ]

  has_many :projects

  validates :name, presence: true, uniqueness: true
end
