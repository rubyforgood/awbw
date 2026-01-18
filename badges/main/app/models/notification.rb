class Notification < ApplicationRecord
  belongs_to :noticeable, polymorphic: true

  # enum notification_type: { created_record: 0, updated_record: 1 } # TODO - convert integer enum data to symbols

  KINDS = %w[
    event_registration_confirmation
    event_registration_confirmation_fyi
    idea_submitted
    idea_submitted_fyi
    report_submitted
    report_submitted_fyi
    workshop_log_submitted
    workshop_log_submitted_fyi
    reset_password
    reset_password_fyi
    account_confirmation_fyi
    account_unlock_fyi
  ].freeze

  RECIPIENT_ROLES = %w[
    admin
    facilitator
  ].freeze

  scope :delivered, -> { where.not(delivered_at: nil) }
  scope :undelivered, -> { where(delivered_at: nil) }

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :recipient_role, presence: true, inclusion: { in: RECIPIENT_ROLES }
  validates :recipient_email, presence: true
  validates :notification_type, presence: true

  def delivered?
    delivered_at.present?
  end
end
