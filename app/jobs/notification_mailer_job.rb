class NotificationMailerJob < ApplicationJob
  queue_as :default

  def perform(notification_id, persist_delivered_email: true)
    notification = Notification.find(notification_id)

    mailer_map = {
      "idea_submitted_fyi"   => ->(n) { NotificationMailer.idea_submitted_fyi(n) },
      "report_submitted_fyi" => ->(n) { NotificationMailer.report_submitted_fyi(n) },
      "workshop_log_submitted_fyi" => ->(n) { NotificationMailer.workshop_log_submitted_fyi(n) },
      "reset_password_fyi"   => ->(n) { NotificationMailer.reset_password_fyi(n) },
      "event_registration_confirmation_fyi" => ->(n) { NotificationMailer.event_registration_confirmation_fyi(n) }
    }

    mailer = mailer_map[notification.kind]&.call(notification)
    raise "Unknown notification kind: #{notification.kind}" unless mailer

    Notification.transaction do
      notification.lock!
      return if notification.delivered_at.present?

      mailer.deliver_now

      if mailer.body.blank?
        Rails.logger.warn("WARNING: Mailer body is empty for Notification #{notification.id} (#{notification.kind})")
      end

      NotificationServices::PersistDeliveredEmail.call(
        notification: notification,
        mail: mailer
      ) if persist_delivered_email
    end
  end
end
