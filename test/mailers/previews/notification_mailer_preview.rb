class NotificationMailerPreview < ActionMailer::Preview

  def event_registration_confirmation_fyi
    event_registration =
      EventRegistration.first ||
        EventRegistration.create!(
          event: Event.first || raise("Need an Event"),
          registrant: User.first || raise("Need a User")
        )

    notification =
      Notification.create!(
        noticeable: event_registration,
        notification_type: 1,
        kind: "event_registration_confirmation_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )

    NotificationMailer.event_registration_confirmation_fyi(notification)
  end

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

  def reset_password_fyi
    notification =
      Notification.create!(
        noticeable: User.first,
        notification_type: 1,
        kind: "reset_password_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )
    NotificationMailer.reset_password_fyi(notification)
  end
end
