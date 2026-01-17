class NotificationMailerJob < ApplicationJob
  queue_as :default

  def perform(notification_id, record_email_delivery: true)
    notification = Notification.find(notification_id)

    mailer_map = {
      "idea_submitted_fyi"   => ->(n) { NotificationMailer.idea_submitted_fyi(n) },
      "report_submitted_fyi" => ->(n) { NotificationMailer.report_submitted_fyi(n) },
      "reset_password_fyi"   => ->(n) { NotificationMailer.reset_password_fyi(n.noticeable) }
    }

    mailer = mailer_map[notification.kind]&.call(notification)

    unless mailer
      raise "Unknown notification kind: #{notification.kind}"
    end

    Notification.transaction do
      notification.lock!
      return if notification.delivered_at.present?

      mailer.deliver_now

      NotificationServices::PersistDeliveredEmail.call(
        notification: notification,
        mail: mailer
      ) if record_email_delivery
    end
  end
end
