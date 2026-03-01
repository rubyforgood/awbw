class EventRegistrationOrganization < ApplicationRecord
  belongs_to :event_registration
  belongs_to :organization

  validates :organization_id, uniqueness: { scope: :event_registration_id }
end
