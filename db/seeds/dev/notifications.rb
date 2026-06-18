# Notification seeds (dev-only) - run on their own via `rake db:seed:notifications`, or
# as part of `rake db:seed:dev`. Seeds contact-us and a few FYI notifications.

puts "Creating Notifications…"
contact_us_samples = [
  { from: "jordan.hayes@example.com", subject: "Question about facilitating Comfort Journals" },
  { from: "priya.patel@example.com",  subject: "Interested in starting a chapter" },
  { from: "sam.wong@example.com",     subject: "Press inquiry — Survivor Voices article" },
  { from: "lee.morgan@example.com",   subject: "Donation receipt request" },
  { from: "chris.alvarez@example.com", subject: "Workshop materials availability" },
  { from: "robin.singh@example.com",  subject: "Volunteer opportunities" }
]

reply_to_email = ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
sample_user = User.where.not(person_id: nil).first

contact_us_samples.each_with_index do |sample, i|
  delivered_at = (contact_us_samples.size - i).days.ago

  Notification.find_or_create_by!(
    recipient_email: sample[:from],
    email_subject: "We received your message",
    kind: "contact_us"
  ) do |n|
    n.noticeable = sample_user&.person
    n.recipient_role = "person"
    n.notification_type = 0
    n.delivered_at = delivered_at
  end

  Notification.find_or_create_by!(
    recipient_email: reply_to_email,
    email_subject: "[FYI] New contact form submission from #{sample[:from]}: #{sample[:subject]}",
    kind: "contact_us_fyi"
  ) do |n|
    n.noticeable = sample_user&.person
    n.recipient_role = "admin"
    n.notification_type = 0
    n.delivered_at = delivered_at
    # Mark older submissions as already responded so the green checks are visible
    n.responded = i < (contact_us_samples.size / 2)
  end
end

# A few non-contact-us notifications so the em-dash rendering is visible too
[
  { kind: "event_registration_confirmation_fyi", subject: "[FYI] New event registration" },
  { kind: "idea_submitted_fyi", subject: "[FYI] New story idea submission by a contributor" },
  { kind: "workshop_log_submitted_fyi", subject: "New WorkshopLog submission" }
].each_with_index do |attrs, i|
  Notification.find_or_create_by!(
    recipient_email: reply_to_email,
    email_subject: attrs[:subject],
    kind: attrs[:kind]
  ) do |n|
    n.noticeable = sample_user&.person
    n.recipient_role = "admin"
    n.notification_type = 0
    n.delivered_at = (i + 1).days.ago
  end
end

puts "  Created #{Notification.where(kind: %w[contact_us contact_us_fyi]).count} contact_us notifications " \
     "(#{Notification.where(kind: 'contact_us_fyi', responded: true).count} marked responded)"

# Custom event reminders Amy received. These demonstrate the editable subject and
# message on the bulk-reminder page: each is a delivered reminder with the
# admin-authored subject/body persisted (rendered through the real mailer, exactly
# as NotificationMailerJob does on a live send), so they appear in Amy's
# registration communications history. Runs after events_management seeds Amy's
# registrations; skips gracefully if that data is absent.
amy_person = User.find_by(email: "amy.user@example.com")&.person

if amy_person && amy_person.preferred_email.present?
  amy_email = amy_person.preferred_email
  organization = ENV.fetch("ORGANIZATION_NAME", "AWBW")

  # Distinct admin-authored messages; paired with separate event registrations so
  # each notification is naturally unique on (noticeable, kind) and idempotent on
  # re-seed.
  reminder_specs = [
    {
      subject: "We can't wait to see you this Saturday 🌿",
      message: "This is a reminder that you're registered for the following #{organization} event <strong>this Saturday</strong>. Doors open 30 minutes early for check-in, and light refreshments will be provided.",
      delivered_days_ago: 9
    },
    {
      subject: "A few things to bring to your session tomorrow",
      message: "Just a friendly nudge ahead of our session <strong>tomorrow</strong>. Please bring an apron and any small keepsake you'd like to work into your art piece.",
      delivered_days_ago: 2
    },
    {
      subject: "Your join link is on the way — virtual session tomorrow",
      message: "We're so glad you're joining us! A reminder that this is a <strong>virtual</strong> session — keep an eye out for the join link on your ticket shortly before we begin.",
      delivered_days_ago: 1
    }
  ]

  amy_reminder_regs = EventRegistration.where(registrant: amy_person)
    .includes(:event)
    .select { |r| r.event&.start_date.present? }
    .sort_by { |r| r.event.start_date }

  amy_reminder_regs.first(reminder_specs.size).each_with_index do |registration, i|
    spec = reminder_specs[i]
    # Admin-edited subject (keeps the portal prefix the page defaults to).
    custom_subject = "#{organization} Portal: #{spec[:subject]}"

    notification = Notification.find_or_create_by!(
      noticeable: registration,
      kind: "event_registration_reminder",
      recipient_email: amy_email
    ) do |n|
      n.recipient_role = "person"
      n.notification_type = 0
      n.custom_message = spec[:message]
      n.custom_subject = custom_subject
    end

    next if notification.delivered_at.present?

    mail = EventMailer.event_registration_reminder(
      registration,
      custom_message: spec[:message],
      custom_subject: custom_subject
    )
    NotificationServices::PersistDeliveredEmail.call(notification: notification, mail: mail)
    # Backdate so the history reads like a sequence of past reminders.
    delivered_at = spec[:delivered_days_ago].days.ago
    notification.update_columns(delivered_at: delivered_at, created_at: delivered_at)
  end

  puts "  Created #{Notification.where(kind: 'event_registration_reminder', recipient_email: amy_email).count} custom event reminders for Amy"
end
