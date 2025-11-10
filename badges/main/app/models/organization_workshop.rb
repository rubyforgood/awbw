class OrganizationWorkshop < ApplicationRecord
  belongs_to :organization
  belongs_to :workshop
end
