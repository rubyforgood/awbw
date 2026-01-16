class EventMailerPreview < ActionMailer::Preview
  def registration_confirmation
    event_registration = EventRegistration.first || FactoryBot.create(:event_registration)

    EventMailer.registration_confirmation(event_registration)
  end
end
