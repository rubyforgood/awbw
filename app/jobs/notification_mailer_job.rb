class NotificationMailerJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.find(notification_id)

    case notification.kind
    when "record_created"
      mailer = NotificationMailer.created_notification(notification)
    when "record_submitted"
      mailer = NotificationMailer.submitted_notification(notification)
    end

    return if notification.delivered_at.present? # Idempotency guard

    mailer.deliver_now

    persist_email(notification, mailer)
  end
end

private

def persist_email(notification, mail)
  notification.update!(
    email_subject: mail.subject,
    email_body_html: mail.html_part&.body&.decoded,
    email_body_text: mail.text_part&.body&.decoded,
    delivered_at: Time.current
  )
end
