class Notification < ApplicationRecord
  belongs_to :noticeable, polymorphic: true, optional: true
  belongs_to :parent_notification, class_name: "Notification", optional: true
  belongs_to :root_notification, class_name: "Notification", optional: true
  has_many :child_notifications, class_name: "Notification", foreign_key: :parent_notification_id, dependent: :nullify

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
    contact_us
    contact_us_fyi
  ].freeze

  RECIPIENT_ROLES = %w[
    admin
    person
  ].freeze

  # Scopes
  scope :delivered, -> { where.not(delivered_at: nil) }
  scope :undelivered, -> { where(delivered_at: nil) }

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :recipient_role, presence: true, inclusion: { in: RECIPIENT_ROLES }
  validates :recipient_email, presence: true
  validates :notification_type, presence: true

  # Scopes
  scope :email, ->(email) { where("notifications.recipient_email LIKE ?", "%#{email}%") }
  scope :participant_name, ->(name) { joins(:people)
      .joins("INNER JOIN users ON users.email = notifications.recipient_email")
      .where("people.name LIKE ?", "%#{name}%") }
  scope :record_type, ->(record_type) { where(noticeable_type: record_type.to_s.camelize.titleize.gsub(" ", "")) }
  scope :subject_line, ->(subject) { where("notifications.email_subject LIKE ?", "%#{subject}%") }

  def self.search_by_params(params)
    stories = is_a?(ActiveRecord::Relation) ? self : all
    stories = stories.email(params[:email]) if params[:email].present?
    stories = stories.participant_name(params[:participant_name]) if params[:participant_name].present?
    stories = stories.subject_line(params[:subject_line]) if params[:subject_line].present?
    stories
  end

  def delivered?
    delivered_at.present?
  end

  def resend_count
    # If this notification has a root, use that; otherwise, this IS the root
    root_id = root_notification_id || id

    # Count all notifications in the chain (excluding the root itself)
    Notification.where(root_notification_id: root_id)
                .where.not(id: root_id)
                .count
  end

  def resend?
    parent_notification_id.present?
  end

  def original_notification
    root_notification || self
  end
end
