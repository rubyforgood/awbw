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

  def callout_form_submitted_fyi
    submission = FormSubmission.order(:id).last ||
      FormSubmission.create!(
        person: Person.first || raise("Need a Person"),
        form: Form.first || raise("Need a Form"),
        event: Event.first,
        role: "post_event_survey"
      )

    NotificationMailer.callout_form_submitted_fyi(submission)
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

  def form_submission_confirmation
    submission = FormSubmission.where(role: "public").order(id: :desc).first ||
      raise("Need a public FormSubmission to preview (run db:seed:public_forms)")

    notification = find_valid_notification("form_submission_confirmation") ||
      Notification.create!(
        noticeable: submission,
        notification_type: 0,
        kind: "form_submission_confirmation",
        recipient_role: "person",
        recipient_email: submission.person.preferred_email
      )

    NotificationMailer.form_submission_confirmation(notification)
  end

  def form_submission_confirmation_fyi
    submission = FormSubmission.where(role: "public").order(id: :desc).first ||
      raise("Need a public FormSubmission to preview (run db:seed:public_forms)")

    notification = find_valid_notification("form_submission_confirmation_fyi") ||
      Notification.create!(
        noticeable: submission,
        notification_type: 0,
        kind: "form_submission_confirmation_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )

    NotificationMailer.form_submission_confirmation_fyi(notification)
  end

  def form_link_request
    person = Person.where.not(email: nil).first || raise("Need a Person with an email")
    form = Form.agreement_forms.first || Form.standalone.first || raise("Need a Form")

    notification = find_valid_notification("form_link_request") ||
      Notification.create!(
        noticeable: person,
        notification_type: 0,
        kind: "form_link_request",
        recipient_role: "person",
        recipient_email: person.preferred_email,
        custom_subject: form.display_name,
        custom_message: "https://portal.awbw.org/f/#{form.slug.presence || "example-form"}",
        sender: User.first
      )

    NotificationMailer.form_link_request(notification)
  end

  def form_submission_confirmation_fyi_anonymous
    submission = FormSubmission.where(role: "public", person_id: nil).order(id: :desc).first ||
      raise("Need an anonymous (person-less) public FormSubmission to preview")

    notification = Notification.new(
      noticeable: submission,
      notification_type: 0,
      kind: "form_submission_confirmation_fyi",
      recipient_role: "admin",
      recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
    )

    NotificationMailer.form_submission_confirmation_fyi(notification)
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

  def profile_change_requested
    request = ProfileChangeRequest.first
    notification = find_valid_notification("profile_change_requested") ||
      Notification.create!(
        noticeable: request,
        notification_type: 0,
        kind: "profile_change_requested",
        recipient_role: "person",
        recipient_email: request&.requested_by&.email || "preview@example.com"
      )
    NotificationMailer.profile_change_requested(notification)
  end

  def profile_change_requested_fyi
    notification = find_valid_notification("profile_change_requested_fyi") ||
      Notification.create!(
        noticeable: ProfileChangeRequest.first,
        notification_type: 0,
        kind: "profile_change_requested_fyi",
        recipient_role: "admin",
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
      )
    NotificationMailer.profile_change_requested_fyi(notification)
  end

  def profile_change_reviewed
    request = ProfileChangeRequest.first
    notification = find_valid_notification("profile_change_reviewed") ||
      Notification.create!(
        noticeable: request,
        notification_type: 0,
        kind: "profile_change_reviewed",
        recipient_role: "person",
        recipient_email: request&.requested_by&.email || "preview@example.com"
      )
    NotificationMailer.profile_change_reviewed(notification)
  end

  private

  def find_valid_notification(kind)
    Notification.where(kind: kind).order(id: :desc).find_each.find(&:noticeable)
  end
end
