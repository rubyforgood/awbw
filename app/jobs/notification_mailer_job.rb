class NotificationMailerJob < ApplicationJob
  queue_as :default

  def perform(notification_id, persist_delivered_email: true)
    notification = Notification.find(notification_id)

    mailer_map = {
      "idea_submitted"       => ->(n) { NotificationMailer.idea_submitted(n) },
      "idea_submitted_fyi"   => ->(n) { NotificationMailer.idea_submitted_fyi(n) },
      "story_promoted"       => ->(n) { NotificationMailer.story_promoted(n) },
      "story_promoted_fyi"   => ->(n) { NotificationMailer.story_promoted_fyi(n) },
      "report_submitted_fyi" => ->(n) { NotificationMailer.report_submitted_fyi(n) },
      "workshop_log_submitted"     => ->(n) { NotificationMailer.workshop_log_submitted(n) },
      "workshop_log_submitted_fyi" => ->(n) { NotificationMailer.workshop_log_submitted_fyi(n) },
      "reset_password_fyi"   => ->(n) { NotificationMailer.reset_password_fyi(n) },
      "event_registration_confirmation" => ->(n) { EventMailer.event_registration_confirmation(n.noticeable) },
      "event_registration_confirmation_fyi" => ->(n) { NotificationMailer.event_registration_confirmation_fyi(n) },
      "event_registration_cancelled" => ->(n) { EventMailer.event_registration_cancelled(n.noticeable) },
      "event_registration_cancelled_fyi" => ->(n) { NotificationMailer.event_registration_cancelled_fyi(n) },
      "event_registration_reminder" => ->(n) { EventMailer.event_registration_reminder(n.noticeable, custom_message: n.custom_message, custom_subject: n.custom_subject, hide_event_card: n.hide_event_card) },
      "event_payment_reminder_week" => ->(n) { EventMailer.event_payment_reminder(n.noticeable, phase: :week) },
      "event_payment_reminder_day" => ->(n) { EventMailer.event_payment_reminder(n.noticeable, phase: :day) },
      "event_payment_reminder_overdue" => ->(n) { EventMailer.event_payment_reminder(n.noticeable, phase: :overdue) },
      "bulk_payment_confirmation" => ->(n) { EventMailer.bulk_payment_confirmation(n.noticeable) },
      "bulk_payment_confirmation_fyi" => ->(n) { NotificationMailer.bulk_payment_confirmation_fyi(n) }
    }

    mailer = mailer_map[notification.kind]&.call(notification)
    raise "Unknown notification kind: #{notification.kind}" unless mailer

    Notification.transaction do
      notification.lock!
      return if notification.delivered_at.present?

      mailer.deliver_now

      NotificationServices::PersistDeliveredEmail.call(
        notification: notification,
        mail: mailer
      ) if persist_delivered_email
    end
  rescue => e
    notification&.record_error!(e)
    raise
  end
end
