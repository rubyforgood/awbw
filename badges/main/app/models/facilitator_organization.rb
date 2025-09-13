class FacilitatorOrganization < ApplicationRecord
  belongs_to :facilitator
  belongs_to :organization
end