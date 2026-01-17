class Notification < ApplicationRecord
  belongs_to :noticeable, polymorphic: true

  after_commit :send_notice
  # enum notification_type: { created_record: 0, updated_record: 1 } # TODO - convert integer enum data to symbols

  KINDS = %w[
    idea_submitted_fyi
    report_submitted_fyi
    password_reset
    password_reset_fyi
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

  def send_notice
    NotificationMailerJob.perform_later(self.id)
  end
end
