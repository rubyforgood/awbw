class ScholarshipAgreementResponse < ApplicationRecord
  # One row per agreement transition (accept ↔ decline ↔ re-offer); the
  # scholarship's agreement_response_status caches the latest row's status.
  STATUSES = %w[pending accepted declined].freeze
  RESPONDERS = %w[recipient admin system].freeze

  belongs_to :scholarship

  validates :status, inclusion: { in: STATUSES }
  validates :responder, inclusion: { in: RESPONDERS }, allow_nil: true
  validates :responded_at, presence: true

  scope :chronological, -> { order(:responded_at, :id) }
end
