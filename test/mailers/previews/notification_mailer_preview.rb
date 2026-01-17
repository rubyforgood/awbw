class NotificationMailerPreview < ActionMailer::Preview
  def idea_submitted_fyi
    noticeable = StoryIdea.first || WorkshopIdea.first
    notification =
      Notification.create!(
        noticeable: noticeable,
        notification_type: 0,
        kind: "idea_submitted_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )
    NotificationMailer.idea_submitted_fyi(notification)
  end

  def report_submitted_fyi
    notification =
      Notification.create!(
        noticeable: WorkshopLog.first || Report.first,
        notification_type: 0,
        kind: "report_submitted_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )

    NotificationMailer.report_submitted_fyi(notification)
  end
end
