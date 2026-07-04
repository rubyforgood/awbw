class Notification < ApplicationRecord
  belongs_to :sender, class_name: "User", optional: true
  belongs_to :noticeable, polymorphic: true, optional: true
  belongs_to :parent_notification, class_name: "Notification", optional: true
  belongs_to :root_notification, class_name: "Notification", optional: true
  has_many :child_notifications, class_name: "Notification", foreign_key: :parent_notification_id, dependent: :nullify

  # enum notification_type: { created_record: 0, updated_record: 1 } # TODO - convert integer enum data to symbols

  KINDS = %w[
    contact_us
    contact_us_fyi

    welcome_instructions
    account_confirmation
    account_confirmation_fyi
    account_email_change_requested
    account_email_changed
    account_confirmed
    account_confirmed_fyi
    account_unlock_fyi
    reset_password
    reset_password_fyi

    event_registration_confirmation
    event_registration_confirmation_fyi
    event_registration_cancelled
    event_registration_cancelled_fyi
    event_registration_reminder
    bulk_payment_confirmation
    bulk_payment_confirmation_fyi
    idea_submitted
    idea_submitted_fyi
    report_submitted
    report_submitted_fyi
    workshop_log_submitted
    workshop_log_submitted_fyi

    manual_log
  ].freeze

  # Channels for a manually logged communication. "autoemail" is the default
  # (an email sent through the system); "email" records a message sent by hand,
  # and phone/text/video are logged after the fact.
  CHANNELS = %w[autoemail email phone text video].freeze

  # Channels an admin can pick when logging a communication by hand. "autoemail"
  # is excluded — it is reserved for email this platform sends automatically.
  MANUAL_CHANNELS = (CHANNELS - %w[autoemail]).freeze

  # Devise-originated kinds that require security tokens and cannot be resent
  # through the notification system. Admins should use Devise's own resend
  # mechanisms (e.g. ProcessEmailManualConfirm) for these.
  DEVISE_KINDS = %w[
    account_confirmation
    reset_password
    welcome_instructions
  ].freeze

  NOTICEABLE_TYPES = %w[
    EventRegistration
    FormSubmission
    Person
    Report
    StoryIdea
    User
    WorkshopLog
    WorkshopIdea
    WorkshopVariation
    WorkshopVariationIdea
  ].freeze

  EMAIL_TOPICS = [
    [ "Admin FYI (all)", "[FYI]" ],
    [ "Admin FYI: event registration confirmed", "[FYI] New event registration" ],
    [ "Admin FYI: event scholarship registration confirmed", "[FYI] New event scholarship registration" ],
    [ "Admin FYI: event registration cancelled", "[FYI] Event registration cancelled" ],
    [ "Admin FYI: event scholarship registration cancelled", "[FYI] Event scholarship registration cancelled" ],
    [ "Admin FYI: bulk payment", "[FYI] New bulk payment" ],
    [ "Admin FYI: idea submitted", "submission by" ],
    [ "Admin FYI: password reset", "[FYI] New password reset" ],
    [ "Admin FYI: workshop log submission", "New WorkshopLog submission" ],
    [ "Admin FYI: contact form submission", "contact form submission" ],
    [ "Contact: form confirmation", "We received your message" ],
    [ "Event registration cancelled", "Event registration cancelled" ],
    [ "Event scholarship registration cancelled", "Event scholarship registration cancelled" ],
    [ "Event registration received", "Event registration received" ],
    [ "Event scholarship registration received", "Event scholarship registration received" ],
    [ "Bulk payment: confirmation", "Bulk payment received" ],
    [ "Idea: confirmation (all)", "has been received" ],
    [ "Idea: confirmation: workshop log", "workshop log has been received" ],
    [ "User: confirm new email", "Confirm your new email address" ],
    [ "User: password reset", "Password reset request" ],
    [ "User: unlock instructions", "Unlock instructions" ],
    [ "User: welcome instructions", "Welcome instructions" ]
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
  validates :channel, inclusion: { in: CHANNELS }, allow_nil: true

  # A manually logged communication (created inline, e.g. from the registration
  # edit page) records a contact that already happened — fill in the sensible
  # defaults so it validates without going through the delivery pipeline.
  before_validation :apply_manual_log_defaults, on: :create, if: -> { kind.blank? }

  def manual_log?
    kind == "manual_log"
  end

  # Scopes
  scope :email, ->(email) { where("notifications.recipient_email LIKE ?", "%#{email}%") }
  scope :participant_name, ->(name) { joins(:people)
      .joins("INNER JOIN users ON users.email = notifications.recipient_email")
      .where("people.name LIKE ?", "%#{name}%") }
  scope :record_type, ->(record_type) { where(noticeable_type: record_type.to_s.camelize.titleize.gsub(" ", "")) }
  scope :subject_line, ->(subject) { where("notifications.email_subject LIKE ?", "%#{subject}%") }
  scope :email_topic, ->(topic) { where("notifications.email_subject LIKE ?", "%#{topic}%") }
  scope :responded_status, ->(status) {
    case status.to_s
    when "yes" then where(kind: "contact_us_fyi", responded: true)
    when "no"  then where(kind: "contact_us_fyi", responded: false)
    when "na"  then where.not(kind: "contact_us_fyi")
    else all
    end
  }

  def self.email_topic_phrase(label)
    EMAIL_TOPICS.assoc(label)&.last
  end

  def self.search_by_params(params)
    stories = is_a?(ActiveRecord::Relation) ? self : all
    stories = stories.email(params[:email]) if params[:email].present?
    stories = stories.participant_name(params[:participant_name]) if params[:participant_name].present?
    stories = stories.subject_line(params[:subject_line]) if params[:subject_line].present?
    topic_phrase = email_topic_phrase(params[:email_topic]) if params[:email_topic].present?
    stories = stories.email_topic(topic_phrase) if topic_phrase.present?
    stories = stories.record_type(params[:record_type]) if params[:record_type].present?
    stories = stories.responded_status(params[:responded_status]) if params[:responded_status].present?
    stories
  end

  def resendable?
    !kind.in?(DEVISE_KINDS)
  end

  def requires_response?
    kind == "contact_us_fyi"
  end

  def delivered?
    delivered_at.present?
  end

  def failed?
    error_at.present? && !delivered?
  end

  def record_error!(exception)
    update!(
      error_message: exception.message.truncate(500),
      error_class: exception.class.name,
      error_at: Time.current
    )
  end

  def resend_count
    # If this notification has a root, use that; otherwise, this IS the root
    root_id = root_notification_id || id

    # Memoize to avoid repeated queries
    @resend_count ||= Notification.where(root_notification_id: root_id)
                                   .where.not(id: root_id)
                                   .count
  end

  def resend?
    parent_notification_id.present?
  end

  def original_notification
    root_notification || self
  end

  # Get the resend number (position in the chain from root)
  # Returns 1 for the first resend, 2 for the second, etc.
  def resend_number
    return nil unless resend?

    # Memoize to avoid repeated queries
    @resend_number ||= begin
      # Get all resent notifications in the chain ordered by creation time
      # (excludes the root notification itself)
      root_id = root_notification_id
      all_resends = Notification.where(root_notification_id: root_id)
                                .order(:created_at)
                                .pluck(:id)

      # Find this notification's position (1-indexed)
      all_resends.index(id) + 1
    end
  end

  private

  def apply_manual_log_defaults
    self.kind = "manual_log"
    self.recipient_role ||= "person"
    self.notification_type ||= 0
    self.delivered_at ||= Time.current
  end
end
