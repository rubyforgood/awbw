class OrganizationStatus < ApplicationRecord
  ORGANIZATION_STATUSES = [ "Active", "Inactive", "Pending", "Reinstate", "Suspended", "Unknown" ]

  # The stored values are kept as-is (legacy data), but the UI collapses them into
  # three "program status" buckets for display and filtering. Anything unmapped —
  # including a missing status — reads as :never_active.
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

  # Stored status names that fall into a given program-status bucket.
  def self.names_for_bucket(bucket)
    PROGRAM_STATUS_BUCKETS.select { |_, value| value == bucket }.keys
  end
end
