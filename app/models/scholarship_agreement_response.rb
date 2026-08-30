class ScholarshipAgreementResponse < ApplicationRecord
  # One row per agreement transition (accept ↔ decline ↔ re-offer); the
  # scholarship's agreement_response_status caches the latest row's status.
  STATUSES = %w[pending accepted declined support_requested].freeze
  RESPONDERS = %w[recipient admin system].freeze

  belongs_to :scholarship
  # The signed-in user who performed the action, when there is one (nil for the
  # public recipient flow). The `responder` role string still records recipient/
  # admin/system regardless.
  belongs_to :responded_by, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :responder, inclusion: { in: RESPONDERS }, allow_nil: true
  validates :responded_at, presence: true

  scope :chronological, -> { order(:responded_at, :id) }
end
