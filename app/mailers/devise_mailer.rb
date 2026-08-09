class DeviseMailer < Devise::Mailer
  layout "mailer"

  helper ApplicationHelper
  include Rails.application.routes.url_helpers

  before_action :set_branding
  after_action :create_notification_record
  after_action :track_devise_email_event

  default from: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
  default reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

  def reset_password_instructions(record, token, opts = {})
    @record = record
    @token  = token
    opts[:subject] = "AWBW Portal: Password reset request for #{record.full_name}"
    @mail   = super
  end

  def confirmation_instructions(record, token, opts = {})
    # The invite sender arrives as a plain id in opts (GlobalID-safe for async
    # delivery); pull it out before super so Devise doesn't fold it into the headers.
    @confirmation_sender_id = opts.delete(:sender_id)
    @record = record
    @token  = token
    @user = record
    @reconfirmation = record.pending_reconfirmation?

    opts[:subject] = if @reconfirmation
      "AWBW Portal: Confirm your new email address"
    else
      "AWBW Portal: Welcome instructions for #{record.full_name}"
    end
    @mail = super
  end

  def unlock_instructions(record, token, opts = {})
    @record = record
    @token  = token
    opts[:subject] = "AWBW Portal: Unlock instructions for #{record.full_name}"
    @mail   = super
  end

  def default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  protected

  def set_branding
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "Our organization")
  end

  private

  def notification_kind_for_devise_action
    {
      "reset_password"              => "reset_password",
      "reset_password_instructions" => "reset_password",
      "confirmation_instructions"   => "account_confirmation",
      "unlock_instructions"         => "account_unlock",
      "welcome_instructions"        => "welcome_invitation"
    }
  end

  def create_notification_record
    return if Rails.env.test?
    return unless @mail && @record

    kind = notification_kind_for_devise_action[action_name]

    # For email changes (reconfirmation), use account_email_change_requested instead
    if action_name == "confirmation_instructions" && @record.try(:pending_reconfirmation?)
      kind = "account_email_change_requested"
    end

    return unless kind # don’t create fyi emails for Devise mailers you don’t care about

    recipient_email = (kind == "account_email_change_requested") ? @record.unconfirmed_email : @record.email

    notification = NotificationServices::CreateNotification.call(
      noticeable: @record,
      recipient_role: :person,
      recipient_email: recipient_email,
      kind: kind,
      notification_type: 1,
      sender: confirmation_sender, # the staff member who triggered it, when one did
      deliver: false # Devise already sent the email, so no need to deliver via the job
    )

    NotificationServices::PersistDeliveredEmail.call(
      notification: notification,
      mail: @mail # record the Devise email that was just sent
    )

    notify_admin_if_needed(kind)
  rescue => e
    Rails.logger.error("DeviseMailer#create_notification_record failed: #{e.message}")
    notification&.record_error!(e) if notification&.persisted?
  end

  def notify_admin_if_needed(kind)
    if kind == "reset_password"
      NotificationServices::CreateNotification.call(
        noticeable: @record,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        kind: "reset_password_fyi",
        notification_type: 1,
        deliver: true
      )
    end
  end

  def track_devise_email_event
    return unless @record.is_a?(User)

    event_name = {
      "reset_password_instructions" => "auth.reset_password_email_sent",
      "confirmation_instructions" => "auth.confirmation_email_sent",
      "unlock_instructions" => "auth.unlock_email_sent"
    }[action_name]

    # For email changes (reconfirmation), use a specific event name
    if action_name == "confirmation_instructions" && @record.try(:pending_reconfirmation?)
      event_name = "auth.email_change_requested_email_sent"
    end

    return unless event_name

    properties = { record_id: @record.id, record_type: "User" }

    if event_name == "auth.email_change_requested_email_sent"
      properties[:changes] = { email: { after: @record.unconfirmed_email } }
    end

    Analytics::AhoyTracker.track_auth_event(
      event_name,
      properties,
      user: confirmation_sender || Current.user
    )
  end

  # The staff member who triggered this confirmation, resolved from the id passed
  # through the mailer opts. Memoized so create_notification_record and
  # track_devise_email_event share one lookup.
  def confirmation_sender
    return @confirmation_sender if defined?(@confirmation_sender)
    @confirmation_sender = @confirmation_sender_id ? User.find_by(id: @confirmation_sender_id) : nil
  end
end
