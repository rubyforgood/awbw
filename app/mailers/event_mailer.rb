class EventMailer < ApplicationMailer
  def event_registration_confirmation(event_registration)
    @event_registration = event_registration
    @event = event_registration.event.decorate
    @user  = event_registration.registrant

    @notification_type = "Event registration confirmation"

    @event_url = event_url(@event)
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "AWBW")
    @organization_website  = ENV.fetch("ORGANIZATION_WEBSITE", unauthenticated_root_url)

    mail(
      to: @user.email,
      from: ENV.fetch("REPLY_TO_EMAIL", "no-reply@awbw.org"),
      reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "Event registration confirmed: #{@event.title}"
    )
  end
end
