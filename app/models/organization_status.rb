class OrganizationStatus < ApplicationRecord
  ORGANIZATION_STATUSES = [ "Active", "Inactive", "Pending", "Reinstate", "Suspended", "Unknown" ]

  # The stored values are legacy: nothing derives an organization's program status
  # from them any more (see ADR-0001 D3). This mapping survives only so the edit
  # form can flag where the stored value contradicts the facilitator affiliations.
  # Anything unmapped — including a missing status — reads as :never_active.
  PROGRAM_STATUS_BUCKETS = {
    "Active" => :active,
    "Reinstate" => :active,
    "Inactive" => :formerly_active,
    "Suspended" => :formerly_active,
    "Pending" => :never_active,
    "Unknown" => :never_active
  }.freeze

  has_many :organizations

  validates :name, presence: true, uniqueness: true

  def self.program_bucket(name)
    PROGRAM_STATUS_BUCKETS.fetch(name.to_s, :never_active)
  end
end
