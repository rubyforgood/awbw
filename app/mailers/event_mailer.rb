class EventMailer < ApplicationMailer
  def event_registration_confirmation(event_registration)
    @event_registration = event_registration
    @event = event_registration.event.decorate
    @person = event_registration.registrant

    @notification_type = "Event registration confirmation"

    @time_zone = @person.user&.time_zone || Time.zone.name
    @event_url = event_url(@event, reg: @event_registration.slug)
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")
    @organization_website  = ENV.fetch("ORGANIZATION_WEBSITE", root_url)

    mail(
      to: @person.preferred_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW Portal: Event registration confirmed for #{@event.title}"
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
      subject: "AWBW Portal: Bulk payment received for #{@event&.title}"
    )
  end

  def event_registration_reminder(event_registration, custom_message: nil, custom_subject: nil, preview: false)
    @event_registration = event_registration
    @event = event_registration.event.decorate
    @person = event_registration.registrant
    @custom_message = custom_message.presence
    @custom_subject = custom_subject.presence
    # When true, the HTML body always renders the custom-message container (even
    # when blank) with hooks the on-page preview's Stimulus controller fills in
    # live. Never set on a real send.
    @preview = preview

    @notification_type = "Event registration reminder"

    @time_zone = @person.user&.time_zone || Time.zone.name
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")
    @organization_website = ENV.fetch("ORGANIZATION_WEBSITE", root_url)

    # Admins can override the subject from the bulk-reminder page; fall back to
    # the standard portal subject (e.g. on a resend that carries no custom value).
    date_suffix = @event.start_date.present? ? " – #{@event.start_date.in_time_zone(@time_zone).strftime('%B %-d, %Y')}" : ""
    default_subject = "AWBW Portal: Reminder: #{@event.title}#{date_suffix}"
    mail(
      to: @person.preferred_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: @custom_subject || default_subject
    )
  end

  # Single admin summary sent once per bulk-reminder send: how many registrants
  # were emailed, who they were, and a copy of the reminder content. The roster
  # is passed as "Name <email>" labels (not records), so the job that delivers
  # this needs no extra lookups. The per-recipient reminders are tracked
  # notifications; this is just an at-a-glance heads-up for the team.
  def event_registration_reminder_fyi(event, recipient_labels, custom_message: nil)
    @event = event.decorate
    @recipient_labels = Array(recipient_labels)
    @custom_message = custom_message.presence
    @notification_type = "Event registration reminder"
    @time_zone = Time.zone.name
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")

    count = @recipient_labels.size
    mail(
      to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW Portal: [FYI] Reminder sent to #{count} registrant#{'s' if count != 1} for #{@event.title}"
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
      subject: "AWBW Portal: Event registration cancelled for #{@event.title}"
    )
  end
end
