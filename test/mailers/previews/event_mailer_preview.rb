class EventMailerPreview < ActionMailer::Preview
  def event_registration_confirmation
    event_registration = sample_event_registration
    EventMailer.event_registration_confirmation(event_registration)
  end

  def event_registration_reminder
    event_registration = sample_event_registration
    EventMailer.event_registration_reminder(
      event_registration,
      custom_message: "This is a reminder that you're registered for the following A Window Between Worlds event <strong>tomorrow</strong>.",
      custom_subject: "A Window Between Worlds Portal: Reminder: see you tomorrow!"
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
    # Try to reuse existing records to avoid duplication. Persist the registration
    # so it has a slug and the confirmation email's "View ticket" link renders
    # (the link is gated on a persisted registration).
    event = Event.first || create_event
    person = Person.first || create_person

    registration = EventRegistration.find_or_create_by!(event: event, registrant: person)
    # Showcase the CE deadlines block (set in memory only, not persisted). The email
    # gates on the event being CE-eligible, so give it offered hours + deadlines. Set
    # on registration.event — the object the mailer decorates and reads.
    registration.event.ce_hours_offered ||= 6
    registration.event.ce_hours_request_deadline ||= 2.weeks.from_now.to_date
    registration.event.ce_payment_due_deadline ||= 3.weeks.from_now.to_date
    registration
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
