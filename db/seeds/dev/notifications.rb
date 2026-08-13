# Notification seeds (dev-only) - run on their own via `rake db:seed:notifications`, or
# as part of `rake db:seed:dev`. Seeds contact-us and a few FYI notifications.

puts "Creating Notifications…"

# Shared HTML wrapper so every seeded body renders like a real (mailer-rendered)
# email in the admin "Email Preview" pane (notifications/show), rather than the
# "No email body captured." placeholder you get when email_body_* is blank.
quoted_block = ->(subject, message) do
  <<~HTML.strip
    <div style="background-color:#f3f4f6;border-radius:6px;padding:12px;margin:16px 0;text-align:left;">
      <p><strong>Subject:</strong> #{subject}</p>
      <p>#{message}</p>
    </div>
  HTML
end

contact_us_samples = [
  { first_name: "Jordan", last_name: "Hayes", from: "jordan.hayes@example.com",
    subject: "Question about facilitating Comfort Journals",
    message: "I recently completed the facilitator training and would love guidance on running my first Comfort Journals workshop. Are there sample session plans you can share?" },
  { first_name: "Priya", last_name: "Patel", from: "priya.patel@example.com",
    subject: "Interested in starting a chapter",
    message: "Our community shelter would like to bring AWBW programming to our residents. What does starting a local chapter involve?" },
  { first_name: "Sam", last_name: "Wong", from: "sam.wong@example.com",
    subject: "Press inquiry — Survivor Voices article",
    message: "I'm writing a feature on trauma-informed art programs and would like to interview someone from your team. What's the best way to coordinate?" },
  { first_name: "Lee", last_name: "Morgan", from: "lee.morgan@example.com",
    subject: "Donation receipt request",
    message: "I made a donation last month but never received a receipt for my records. Could you resend it to this address?" },
  { first_name: "Chris", last_name: "Alvarez", from: "chris.alvarez@example.com",
    subject: "Workshop materials availability",
    message: "Do you ship the workshop supply kits internationally, or are they only available within the US?" },
  { first_name: "Robin", last_name: "Singh", from: "robin.singh@example.com",
    subject: "Volunteer opportunities",
    message: "I have a background in counseling and would like to volunteer. Where can I learn about current openings?" }
]

reply_to_email = ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
sample_user = User.where.not(person_id: nil).first

contact_us_samples.each_with_index do |sample, i|
  delivered_at = (contact_us_samples.size - i).days.ago

  confirmation_html = <<~HTML.strip
    <h1>We received your message</h1>
    <p>Hello #{sample[:first_name]},</p>
    <p>Thank you for reaching out. A member of our team will review your inquiry and get back to you as soon as possible.</p>
    #{quoted_block.call(sample[:subject], sample[:message])}
    <p>In community,<br>AWBW Programs</p>
  HTML
  confirmation_text = <<~TEXT.strip
    We received your message

    Hello #{sample[:first_name]},

    Thank you for reaching out. A member of our team will review your inquiry and get back to you as soon as possible.

    Subject: #{sample[:subject]}
    #{sample[:message]}

    In community,
    AWBW Programs
  TEXT

  confirmation = Notification.find_or_create_by!(
    recipient_email: sample[:from],
    email_subject: "We received your message",
    kind: "contact_us"
  ) do |n|
    n.noticeable = sample_user&.person
    n.recipient_role = "person"
    n.notification_type = 0
    n.delivered_at = delivered_at
    n.email_body_html = confirmation_html
    n.email_body_text = confirmation_text
  end
  # Backfill bodies on records seeded before email_body_* was added here
  confirmation.update!(email_body_html: confirmation_html, email_body_text: confirmation_text) if confirmation.email_body_html.blank?

  fyi_html = <<~HTML.strip
    <h1>New contact form submission</h1>
    <p><strong>#{sample[:first_name]} #{sample[:last_name]}</strong> has submitted a message through the contact form.</p>
    <p><strong>Email:</strong> #{sample[:from]}</p>
    #{quoted_block.call(sample[:subject], sample[:message])}
  HTML
  fyi_text = <<~TEXT.strip
    New contact form submission

    #{sample[:first_name]} #{sample[:last_name]} has submitted a message through the contact form.

    Email: #{sample[:from]}

    Subject: #{sample[:subject]}
    #{sample[:message]}
  TEXT

  fyi = Notification.find_or_create_by!(
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
    n.email_body_html = fyi_html
    n.email_body_text = fyi_text
  end
  fyi.update!(email_body_html: fyi_html, email_body_text: fyi_text) if fyi.email_body_html.blank?
end

# A few non-contact-us notifications so the em-dash rendering is visible too
[
  { kind: "event_registration_confirmation_fyi", subject: "[FYI] New event registration",
    body: "A new event registration has been submitted through the portal. Review the registrant's details and form answers in the events dashboard." },
  { kind: "idea_submitted_fyi", subject: "[FYI] New story idea submission by a contributor",
    body: "A contributor has submitted a new story idea. Review the submission and any attached quotes or images in the admin area." },
  { kind: "workshop_log_submitted_fyi", subject: "New WorkshopLog submission",
    body: "A facilitator has logged a completed workshop. Review the session details and participant counts in the reporting dashboard." }
].each_with_index do |attrs, i|
  body_html = "<h1>#{attrs[:subject]}</h1>\n<p>#{attrs[:body]}</p>"
  body_text = "#{attrs[:subject]}\n\n#{attrs[:body]}"

  notification = Notification.find_or_create_by!(
    recipient_email: reply_to_email,
    email_subject: attrs[:subject],
    kind: attrs[:kind]
  ) do |n|
    n.noticeable = sample_user&.person
    n.recipient_role = "admin"
    n.notification_type = 0
    n.delivered_at = (i + 1).days.ago
    n.email_body_html = body_html
    n.email_body_text = body_text
  end
  notification.update!(email_body_html: body_html, email_body_text: body_text) if notification.email_body_html.blank?
end

# A few emails that never went out, so the warning styling is visible: the index
# tints the whole row (and the detail card) amber for a stuck-pending email and
# red for a failed one. Created a few hours ago so they sort to the top (index is
# created_at desc) and are past the 1-hour delivery grace period, so the pending
# ones read as stuck rather than fresh. Left undelivered with no subject/body —
# exactly the state a real stuck or failed send leaves behind.
delivery_problem_samples = [
  { kind: "idea_submitted_fyi", hours_ago: 2, state: :failed },
  { kind: "workshop_log_submitted_fyi", hours_ago: 3, state: :pending },
  { kind: "event_registration_confirmation_fyi", hours_ago: 4, state: :pending }
]

delivery_problem_samples.each do |sample|
  created_at = sample[:hours_ago].hours.ago
  failed = sample[:state] == :failed

  notification = Notification.find_or_create_by!(
    recipient_email: reply_to_email,
    kind: sample[:kind],
    email_subject: nil
  ) do |n|
    n.noticeable = sample_user&.person
    n.recipient_role = "admin"
    n.notification_type = 0
    n.delivered_at = nil
    n.error_at = failed ? created_at : nil
    n.error_class = failed ? "Net::SMTPServerBusy" : nil
    n.error_message = failed ? "451 Temporary server error. Please try again later." : nil
  end
  # Re-anchor to a fresh few-hours-ago each seed run so they stay at the top.
  notification.update_columns(created_at: created_at)
end

puts "  Created #{delivery_problem_samples.size} undelivered notifications (pending → warning, failed → error styling)"

puts "  Created #{Notification.where(kind: %w[contact_us contact_us_fyi]).count} contact_us notifications"

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
