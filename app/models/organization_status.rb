class OrganizationStatus < ApplicationRecord
  ORGANIZATION_STATUSES = [ "Active", "Inactive", "Pending", "Reinstate", "Suspended", "Unknown" ]

  has_many :organizations

  validates :name, presence: true, uniqueness: true
end
