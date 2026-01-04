class NotificationMailerPreview < ActionMailer::Preview
  def created_notification
    notification = Notification.last ||
      Notification.create!(
        noticeable: StoryIdea.first || WorkshopLog.first || Report.first,
        notification_type: "created_record",
        kind: "record_created",
        recipient_role: "admin",
        recipient_email: "programs@awbw.org"
      )
    NotificationMailer.created_notification(notification)
  end

  def report_notification
    notification = Notification.last ||
      Notification.create!(
        noticeable: WorkshopLog.first || Report.first,
        notification_type: "created_record",
        kind: "record_created",
        recipient_role: "admin",
        recipient_email: "programs@awbw.org"
      )

    NotificationMailer.report_notification(notification)
  end
end
