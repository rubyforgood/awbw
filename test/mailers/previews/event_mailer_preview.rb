class EventMailerPreview < ActionMailer::Preview
  def event_registration_confirmation
    event_registration = sample_event_registration
    EventMailer.event_registration_confirmation(event_registration)
  end

  private

  def sample_event_registration
    # Try to reuse existing records to avoid duplication
    event = Event.first || create_event
    user  = User.first  || create_user

    EventRegistration.new(
      event: event,
      registrant: user
    )
  end

  def create_event
    Event.create!(
      title: "Community Art Workshop",
      detail: "Join us for a hands-on creative session focused on self-expression.",
      start_time: 3.days.from_now,
      end_time: 3.days.from_now + 2.hours
    )
  end

  def create_user
    User.create!(
      email: "participant@example.org",
      first_name: "Alex",
      last_name: "Rivera",
      password: "password123"
    )
  end
end
