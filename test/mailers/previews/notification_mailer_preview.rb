class NotificationMailerPreview < ActionMailer::Preview
  def idea_submitted_fyi
    notification = Notification.last ||
      Notification.create!(
        noticeable: StoryIdea.first || WorkshopLog.first || Report.first,
        notification_type: "created_record",
        kind: "record_created",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )
    NotificationMailer.idea_submitted_fyi(notification)
  end

  def report_submitted_fyi
    notification =
      Notification.create!(
        noticeable: WorkshopLog.first || Report.first,
        notification_type: "created_record",
        kind: "record_created",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )

    NotificationMailer.report_submitted_fyi(notification)
  end
end
