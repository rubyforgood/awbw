class EventMailer < ApplicationMailer
  def event_registration_confirmation(event_registration)
    @event_registration = event_registration
    @event = event_registration.event.decorate
    @person = event_registration.registrant

    @notification_type = "Event registration confirmation"

    @time_zone = @person.user&.time_zone || Time.zone.name
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")
    @organization_website  = ENV.fetch("ORGANIZATION_WEBSITE", root_url)

    mail(
      to: @person.preferred_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW Portal: #{@event_registration.registration_subject_noun.capitalize} received for #{@event.title}"
    )
  end

  def bulk_payment_confirmation(form_submission)
    @submission = form_submission
    @person = form_submission.person
    @event = form_submission.event&.decorate
    @answers = form_submission.answers_by_identifier
    @attendees = form_submission.bulk_payment_attendees
    # Expected total (event cost × attendee count), shown even before a payment
    # record lands. Mirrors the ticket page; omitted when there's no event/cost.
    @total_cents = form_submission.event && form_submission.bulk_payment_amount_cents(form_submission.event)

    @notification_type = "Bulk payment confirmation"

    # Like the registration confirmation, the payer is sent to their ticket (which
    # carries the event details + a "View submission" link). Bulk payments always
    # have an event; guard anyway so an event-less submission just omits the link.
    @ticket_url = bulk_payment_ticket_url(@submission.slug) if @submission.event.present? && @submission.slug.present?
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")

    mail(
      to: @person.preferred_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW Portal: Payment received for #{@event&.title}"
    )
  end

  def event_registration_reminder(event_registration, custom_message: nil, custom_subject: nil, hide_event_card: false, hide_ticket_button: false, preview: false)
    @event_registration = event_registration
    @event = event_registration.event.decorate
    @person = event_registration.registrant
    @custom_message = custom_message.presence
    @custom_subject = custom_subject.presence
    # When true, the grey event-details card is dropped from the email — the admin
    # chose to send a plainer message on the bulk-reminder page.
    @hide_event_card = hide_event_card
    # When true, the "View ticket" button (and its lead-in line) is dropped — the
    # admin chose a plain informational email with no link to the registrant's ticket.
    @hide_ticket_button = hide_ticket_button
    # When true, the HTML body always renders the custom-message container (even
    # when blank) with hooks the on-page preview's Stimulus controller fills in
    # live. Never set on a real send.
    @preview = preview

    @notification_type = "Event registration reminder"

    @time_zone = @person.user&.time_zone || Time.zone.name
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")
    @organization_website = ENV.fetch("ORGANIZATION_WEBSITE", root_url)

    # Admins can override the subject from the bulk-reminder page; fall back to
    # the standard portal subject when they left it blank. Shared with the compose
    # page's pre-fill so the preview and the delivered email can't drift apart.
    mail(
      to: @person.preferred_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: @custom_subject || @event.default_reminder_subject(time_zone: @time_zone)
    )
  end

  # The bulk-reminder counterpart for a "Pay for Others" submitter. They have no
  # ticket of their own, so instead of a registration reminder they get a nudge
  # to their public payment ticket (attendees + total). Shares the admin's custom
  # subject/message with the registrant reminder so one compose drives both.
  def event_bulk_payment_reminder(form_submission, custom_message: nil, custom_subject: nil, preview: false)
    @submission = form_submission
    @person = form_submission.person
    @event = form_submission.event&.decorate
    @answers = form_submission.answers_by_identifier
    @attendee_count = form_submission.bulk_payment_attendee_count
    @custom_message = custom_message.presence
    @custom_subject = custom_subject.presence
    # See event_registration_reminder: renders the live-preview message container
    # even when blank. Never set on a real send.
    @preview = preview

    @notification_type = "Event bulk payment reminder"

    @time_zone = @person&.user&.time_zone || Time.zone.name
    @ticket_url = bulk_payment_ticket_url(@submission.slug) if @submission.event.present? && @submission.slug.present?
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")

    default_subject = "AWBW Portal: Reminder: complete your payment for #{@event&.title}"
    mail(
      to: form_submission.bulk_payment_reminder_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: @custom_subject || default_subject
    )
  end

  # Single admin summary sent once per bulk-reminder send: how many people were
  # emailed, who they were, and a copy of the reminder content. Recipients span
  # both registrants and Pay-for-Others submitters, so the roster is passed as
  # "Name <email>" labels (not records) and the count uses the neutral noun
  # "recipient". The per-recipient reminders are tracked notifications; this is
  # just an at-a-glance heads-up for the team.
  def event_registration_reminder_fyi(event, recipient_labels, custom_message: nil, hide_event_card: false, hide_ticket_button: false)
    @event = event.decorate
    @recipient_labels = Array(recipient_labels)
    @custom_message = custom_message.presence
    # Mirror what registrants received: drop the card from the admin copy too.
    @hide_event_card = hide_event_card
    # Mirror what registrants received: note the ticket link only when it was sent.
    @hide_ticket_button = hide_ticket_button
    @notification_type = "Event registration reminder"
    @time_zone = Time.zone.name
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")

    count = @recipient_labels.size
    mail(
      to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW Portal: [FYI] Reminder sent to #{count} recipient#{'s' if count != 1} for #{@event.title}"
    )
  end

  def event_registration_cancelled(event_registration)
    @event_registration = event_registration
    @event = event_registration.event.decorate
    @person = event_registration.registrant

    @notification_type = "Event registration cancellation"

    @time_zone = @person.user&.time_zone || Time.zone.name
    @event_url = event_url(@event, reg: @event_registration.slug)
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")

    mail(
      to: @person.preferred_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW Portal: #{@event_registration.registration_subject_noun.capitalize} cancelled for #{@event.title}"
    )
  end
end
