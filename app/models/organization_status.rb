class OrganizationStatus < ApplicationRecord
  ORGANIZATION_STATUSES = [ "Active", "Formerly active", "Unknown" ]

  has_many :organizations

  validates :name, presence: true, uniqueness: true
end
