module NotificationServices
  class CreateNotification
    def self.call(
      noticeable:,
      recipient_role:,
      recipient_email:,
      kind:,
      notification_type:,
      deliver: true,
      persist_delivered_email: true
    )
      # create the notification record
      notification = Notification.create!(
        noticeable: noticeable,
        kind: kind.to_s,
        notification_type: notification_type,
        recipient_role: recipient_role.to_s,
        recipient_email: recipient_email
      )

      # send an email, and then persist it to the notification
      NotificationMailerJob.perform_later(notification.id, persist_delivered_email: persist_delivered_email) if deliver

      notification
    end
  end
end
