# Resource seeds (dev-only) - run on their own via `rake db:seed:resources`, or as
# part of `rake db:seed:dev`.

# Faker is installed but not auto-required on staging, where the app runs as
# RAILS_ENV=production and Bundler.require only loads the production group.
require "faker"

puts "Creating Resources…"
10.times do |i|
  kind = Resource::PUBLISHED_KINDS.sample

  visibility = if i < 3
    { published: true, featured: true }
  elsif i < 6
    { published: true, publicly_visible: true, publicly_featured: true }
  else
    { published: [ true, true, false ].sample, featured: [ true, false ].sample,
      publicly_visible: [ true, false ].sample, publicly_featured: [ true, false ].sample }
  end

  resource_body = Faker::Lorem.paragraph(sentence_count: 8)
  Resource.where(title: Faker::Book.title).first_or_create!(
    body: resource_body,
    rhino_body: resource_body,
    author: [ Person.all.sample, nil, nil ].sample,
    author_credit_preference: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES.sample,
    legacy_author_name: [ Faker::Name.name, nil, nil ].sample,
    agency: [ Faker::Company.name, nil ].sample,
    kind: kind,
    url: [ "https://example.com/resource/#{SecureRandom.hex(4)}", nil ].sample,
    inactive: false,
    legacy: [ true, false, false ].sample,
    legacy_id: rand(1000..9999),
    position: rand(1..50),
    windows_type_id: WindowsType.all.sample&.id,
    workshop_id: Workshop.all.sample&.id,
    created_by_id: User.all.sample&.id,
    created_at: Time.current - rand(20..120).days,
    updated_at: Time.current - rand(1..40).days,
    **visibility
  )
end

# Hidden resources: publicly accessible by direct link, but excluded from
# non-admin portal searches/listings (hidden_from_search). Each ships with a
# downloadable PDF stored under db/seeds/dev/files.
puts "Creating hidden Resources…"
hidden_resources = [
  {
    title: "AWBW Training Workshop Worksheets",
    body: "Printable worksheets used in AWBW training workshops, including the Touchstone Journey exercise.",
    filename: "awbw_training_workshop_worksheets.pdf"
  },
  {
    title: "AHA Moments",
    body: "A facilitation worksheet for capturing insights and reflections during AWBW art workshops.",
    filename: "aha_moments.pdf"
  },
  {
    title: "2-Day AWBW Facilitator Training Worksheets & Handouts",
    body: "The complete packet of worksheets and handouts for the 2-day AWBW Facilitator Training.",
    filename: "two_day_training_worksheets_and_handouts.pdf"
  },
  {
    title: "Inviting and Responding to Participants' Sharing",
    body: "Guidance for holding space and responding to participant sharing in breakout rooms.",
    filename: "inviting_and_responding_to_sharing.pdf"
  },
  {
    title: "Letter to Supervisors",
    body: "A letter trainees can share with supervisors to request release time for the training.",
    filename: "letter_to_supervisors.pdf",
    kind: "Form"
  },
  {
    title: "W-9",
    body: "AWBW's W-9 tax form for trainees' records.",
    filename: "w9.pdf",
    kind: "Form"
  }
]

hidden_resources.each do |attrs|
  resource = Resource.where(title: attrs[:title]).first_or_create!(
    body: attrs[:body],
    rhino_body: attrs[:body],
    agency: "A Window Between Worlds",
    kind: attrs.fetch(:kind, "Handout"),
    inactive: false,
    published: true,
    publicly_visible: true,
    hidden_from_search: true,
    created_by_id: User.all.sample&.id,
    created_at: Time.current - rand(0..2).days
  )

  next if resource.downloadable_asset&.file&.attached?

  asset = resource.downloadable_asset || resource.build_downloadable_asset
  asset.file.attach(
    io: File.open(Rails.root.join("db/seeds/dev/files", attrs[:filename])),
    filename: attrs[:filename],
    content_type: "application/pdf"
  )
  asset.save!
end

# The training-topic resources the survey clarity questions fan out over. In prod
# these already exist; locally we create minimal records so the seeded links form.
puts "Creating survey clarity topic resources…"
SurveyFormSeeder::FANOUT_RESOURCES.flat_map { |entry| entry[:resources] }.uniq.each do |title|
  Resource.where(title: title).first_or_create!(kind: "Handout", published: true,
    created_by_id: User.all.sample&.id)
end
SurveyFormSeeder.new.link_fanout_resources

# Link AWBW's W-9 to every paid event's payment callout so registrants can
# download it from the payment page before paying (they often need it to register
# AWBW as a vendor first). The payment callout materializes in events_management,
# which seeds before this file creates the W-9, so the link is healed here.
# Idempotent: skips a callout that already carries the W-9.
puts "Linking the W-9 to paid events' payment callouts…"
w9 = Resource.find_by(title: "W-9")
if w9
  Event.where("cost_cents > ?", 0).find_each do |paid_event|
    payment = paid_event.registration_ticket_callouts.find_by(builtin_key: "payment")
    next unless payment
    next if payment.resources.exists?(id: w9.id)
    payment.registration_ticket_callout_resources.create!(
      resource: w9, subtitle: "AWBW's W-9 tax form for your records"
    )
  end
end
