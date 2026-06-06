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
