class EventMailer < ApplicationMailer
  def event_registration_confirmation(event_registration)
    @event_registration = event_registration
    @event = event_registration.event.decorate
    @person = event_registration.registrant

    @notification_type = "Event registration confirmation"

    @time_zone = @person.user&.time_zone || Time.zone.name
    @event_url = event_url(@event)
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")
    @organization_website  = ENV.fetch("ORGANIZATION_WEBSITE", root_url)

    mail(
      to: @person.preferred_email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW portal: Event registration confirmed for #{@event.title}"
    )
  end
end
