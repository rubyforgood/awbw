class DeviseMailer < Devise::Mailer
  layout "mailer"

  helper ApplicationHelper
  include Rails.application.routes.url_helpers

  before_action :set_branding
  after_action :create_notification_record

  default from: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
  default reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

  def reset_password_instructions(record, token, opts = {})
    @record = record
    @token  = token
    @mail   = super
  end

  def confirmation_instructions(record, token, opts = {})
    @record = record
    @token  = token
    @mail   = super
  end

  def unlock_instructions(record, token, opts = {})
    @record = record
    @token  = token
    @mail   = super
  end

  def default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  protected

  def set_branding
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "Our organization")
  end

  def headers_for(action, opts)
    headers = super
    headers[:subject] = I18n.t(
      "devise.mailer.#{action}.subject",
      organization_name: @organization_name
    )
    headers
  end

  private

  def notification_kind_for_devise_action
    {
      "reset_password_instructions" => "reset_password",
      "confirmation_instructions"   => "account_confirmation",
      "unlock_instructions"         => "account_unlock"
    }
  end

  def create_notification_record
    return unless @mail && @record

    kind = notification_kind_for_devise_action[action_name]
    return unless kind # don't create fyi emails for Devise mailers you don’t care about

    notification = NotificationServices::CreateNotification.call(
      noticeable: @record,
      recipient_role: "facilitator",
      recipient_email: @record.email,
      kind: kind,
      notification_type: 1,
      deliver: false # Devise already sent the email, so no need to deliver via the job
    )

    NotificationServices::PersistDeliveredEmail.call(
      notification: notification,
      mail: @mail # record the Devise email that was just sent
    )

    notify_admin_if_needed(kind)
  end


  def notify_admin_if_needed(kind)
    if kind == "reset_password"
      NotificationServices::CreateNotification.call(
        noticeable: @record,
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        kind: "reset_password_fyi",
        notification_type: 1,
        deliver: true
      )
    end
  end
end
