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

    @notification_type = "Bulk payment confirmation"

    @submission_url = bulk_payment_ticket_url(@submission.slug) if @submission.slug.present?
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")

    mail(
      to: @person.preferred_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW Portal: Bulk payment received for #{@event&.title}"
    )
  end

  def event_registration_reminder(event_registration, days_until_event: nil)
    @event_registration = event_registration
    @event = event_registration.event.decorate
    @person = event_registration.registrant
    @days_until_event = days_until_event

    @notification_type = "Event registration reminder"

    @time_zone = @person.user&.time_zone || Time.zone.name
    @event_url = @event_registration.slug.present? ? event_url(@event, reg: @event_registration.slug) : event_url(@event)
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")
    @organization_website = ENV.fetch("ORGANIZATION_WEBSITE", root_url)

    subject = "Reminder: #{@event.title} – #{@event.start_date.in_time_zone(@time_zone).strftime('%B %-d, %Y')}"
    mail(
      to: @person.preferred_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW Portal: #{subject}"
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
