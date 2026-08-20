module NotificationServices
  class CreateNotification
    def self.call(
      noticeable:,
      recipient_role:,
      recipient_email:,
      kind:,
      notification_type:,
      custom_message: nil,
      custom_subject: nil,
      hide_event_card: false,
      sender: nil,
      bulk: false,
      deliver: true,
      persist_delivered_email: true
    )
      # create the notification record
      notification = Notification.create!(
        noticeable: noticeable,
        kind: kind.to_s,
        notification_type: notification_type,
        recipient_role: recipient_role.to_s,
        recipient_email: recipient_email,
        custom_message: custom_message,
        custom_subject: custom_subject,
        hide_event_card: hide_event_card,
        sender: sender,
        bulk: bulk
      )
      Rails.logger.info({
                          event: "notification.created",
                          notification_id: notification.id,
                          caused_by_event: kind.to_s,
                          actor_user_id: noticeable.try(:created_by_id),
                          recipient_email: recipient_email,
                          noticeable_type: noticeable&.class&.name,
                          noticeable_id: noticeable&.id
                        }.to_json)

      # send an email, and then persist it to the notification
      NotificationMailerJob.perform_later(notification.id, persist_delivered_email: persist_delivered_email) if deliver

      notification
    end
  end
end
