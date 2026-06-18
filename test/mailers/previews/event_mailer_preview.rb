class EventMailerPreview < ActionMailer::Preview
  def event_registration_confirmation
    event_registration = sample_event_registration
    EventMailer.event_registration_confirmation(event_registration)
  end

  def event_registration_reminder
    event_registration = sample_event_registration
    EventMailer.event_registration_reminder(
      event_registration,
      custom_message: "This is a reminder that you're registered for the following A Window Between Worlds event <strong>tomorrow</strong>."
    )
  end

  def event_registration_reminder_fyi
    event = Event.first || create_event
    EventMailer.event_registration_reminder_fyi(
      event,
      [ "Alex Rivera <alex@example.org>", "Sam Lee <sam@example.org>" ],
      custom_message: "This is a reminder that you're registered for the following A Window Between Worlds event <strong>tomorrow</strong>."
    )
  end

  def event_registration_cancelled
    event_registration = sample_event_registration
    event_registration.status = "cancelled"
    EventMailer.event_registration_cancelled(event_registration)
  end

  def bulk_payment_confirmation
    EventMailer.bulk_payment_confirmation(sample_bulk_payment_submission)
  end

  private

  def sample_bulk_payment_submission
    FormSubmission.where(role: "bulk_payment").order(id: :desc).find_each.find(&:event) ||
      FormSubmission.where(role: "bulk_payment").order(id: :desc).first ||
      raise("Need a bulk_payment FormSubmission to preview")
  end

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
