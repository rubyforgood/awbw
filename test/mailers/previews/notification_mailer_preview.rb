class NotificationMailerPreview < ActionMailer::Preview
  def event_registration_confirmation_fyi
    event_registration =
      EventRegistration.first ||
        EventRegistration.create!(
          event: Event.first || raise("Need an Event"),
          registrant: User.first || raise("Need a User")
        )

    notification = find_valid_notification("event_registration_confirmation_fyi") ||
      Notification.create!(
        noticeable: event_registration,
        notification_type: 1,
        kind: "event_registration_confirmation_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )

    NotificationMailer.event_registration_confirmation_fyi(notification)
  end

  def event_registration_cancelled_fyi
    event_registration =
      EventRegistration.first ||
        EventRegistration.create!(
          event: Event.first || raise("Need an Event"),
          registrant: User.first || raise("Need a User")
        )

    notification = find_valid_notification("event_registration_cancelled_fyi") ||
      Notification.create!(
        noticeable: event_registration,
        notification_type: 1,
        kind: "event_registration_cancelled_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )

    NotificationMailer.event_registration_cancelled_fyi(notification)
  end

  def bulk_payment_confirmation_fyi
    submission = FormSubmission.where(role: "bulk_payment").order(id: :desc).first ||
      raise("Need a bulk_payment FormSubmission to preview")

    notification = find_valid_notification("bulk_payment_confirmation_fyi") ||
      Notification.create!(
        noticeable: submission,
        notification_type: 0,
        kind: "bulk_payment_confirmation_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )

    NotificationMailer.bulk_payment_confirmation_fyi(notification)
  end

  def idea_submitted
    noticeable = StoryIdea.first || WorkshopVariationIdea.first
    user = noticeable&.created_by || User.first
    notification = find_valid_notification("idea_submitted") ||
      Notification.create!(
        noticeable: noticeable || User.first,
        notification_type: 0,
        kind: "idea_submitted",
        recipient_role: "person",
        recipient_email: user&.email || "preview@example.com"
      )
    NotificationMailer.idea_submitted(notification)
  end

  def idea_submitted_fyi
    noticeable = StoryIdea.first || WorkshopVariationIdea.first
    notification = find_valid_notification("idea_submitted_fyi") ||
      Notification.create!(
        noticeable: noticeable,
        notification_type: 0,
        kind: "idea_submitted_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )
    NotificationMailer.idea_submitted_fyi(notification)
  end

  def story_promoted
    story = Story.where.not(story_idea_id: nil).first || Story.first
    user = story&.story_idea&.created_by || story&.created_by || User.first
    notification = find_valid_notification("story_promoted") ||
      Notification.create!(
        noticeable: story,
        notification_type: 0,
        kind: "story_promoted",
        recipient_role: "person",
        recipient_email: user&.email || "preview@example.com"
      )
    NotificationMailer.story_promoted(notification)
  end

  def story_promoted_fyi
    story = Story.where.not(story_idea_id: nil).first || Story.first
    notification = find_valid_notification("story_promoted_fyi") ||
      Notification.create!(
        noticeable: story,
        notification_type: 0,
        kind: "story_promoted_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )
    NotificationMailer.story_promoted_fyi(notification)
  end

  def report_submitted_fyi
    notification = find_valid_notification("report_submitted_fyi") ||
      Notification.create!(
        noticeable: Report.where.not(type: "WorkshopLog").first || Report.first || WorkshopLog.first,
        notification_type: 0,
        kind: "report_submitted_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )

    NotificationMailer.report_submitted_fyi(notification)
  end

  def reset_password_fyi
    notification = find_valid_notification("reset_password_fyi") ||
      Notification.create!(
        noticeable: User.first,
        notification_type: 1,
        kind: "reset_password_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )
    NotificationMailer.reset_password_fyi(notification)
  end


  def workshop_log_submitted
    noticeable = WorkshopLog.first || Report.first
    user = noticeable&.created_by || User.first
    notification = find_valid_notification("workshop_log_submitted") ||
      Notification.create!(
        noticeable: noticeable || User.first,
        notification_type: 0,
        kind: "workshop_log_submitted",
        recipient_role: "person",
        recipient_email: user&.email || "preview@example.com"
      )
    NotificationMailer.workshop_log_submitted(notification)
  end

  def workshop_log_submitted_fyi
    notification = find_valid_notification("workshop_log_submitted_fyi") ||
      Notification.create!(
        noticeable: WorkshopLog.first || Report.first,
        notification_type: 0,
        kind: "workshop_log_submitted_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )

    NotificationMailer.workshop_log_submitted_fyi(notification)
  end

  private

  def find_valid_notification(kind)
    Notification.where(kind: kind).order(id: :desc).find_each.find(&:noticeable)
  end
end
