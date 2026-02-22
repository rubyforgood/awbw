class EventMailerPreview < ActionMailer::Preview
  def event_registration_confirmation
    event_registration = sample_event_registration
    EventMailer.event_registration_confirmation(event_registration)
  end

  private

  def sample_event_registration
    # Try to reuse existing records to avoid duplication
    event = Event.first || create_event
    person = Person.first || create_person

    EventRegistration.new(
      event: event,
      registrant: person
    )
  end

  def create_event
    location = Location.first || Location.create!(city: "Sheboygan", state: "WI")
    Event.create!(
      title: "Community Art Workshop",
      start_date: 3.days.from_now,
      end_date: 3.days.from_now + 2.hours,
      published: true,
      location: location,
      videoconference_url: "https://example.com/meeting/123"
    )
  end

  def create_person
    user = User.create!(
      email: "participant@example.org",
      first_name: "Alex",
      last_name: "Rivera",
      password: "password123"
    )
    user.person
  end
end
