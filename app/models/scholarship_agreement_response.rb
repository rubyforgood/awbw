class ScholarshipAgreementResponse < ApplicationRecord
  # One row per agreement transition, so the back-and-forth between a recipient
  # and the team (accept ↔ decline, and admin re-offers) is a first-class,
  # queryable history. The scholarship's agreement_response_status is the
  # denormalized cache of the latest row here.
  STATUSES = %w[pending accepted declined].freeze
  RESPONDERS = %w[recipient admin system].freeze

  belongs_to :scholarship
  # The admin FYI this response produced, when one was sent (accepts and declines).
  belongs_to :notification, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :responder, inclusion: { in: RESPONDERS }, allow_nil: true
  validates :responded_at, presence: true

  scope :chronological, -> { order(:responded_at, :id) }
end
