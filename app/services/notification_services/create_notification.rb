module NotificationServices
  class CreateNotification
    def self.call(
      noticeable:,
      recipient_role:,
      recipient_email:,
      kind:,
      notification_type:,
      deliver: true,
      record_email_delivery: true
    )
      notification = Notification.create!(
        noticeable: noticeable,
        kind: kind.to_s,
        notification_type: notification_type,
        recipient_role: recipient_role.to_s,
        recipient_email: recipient_email
      )

      NotificationMailerJob.perform_later(notification.id, record_email_delivery: record_email_delivery) if deliver

      notification
    end
  end
end
