# Resource seeds (dev-only) - run on their own via `rake db:seed:resources`, or as
# part of `rake db:seed:dev`.

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
    author: [ Faker::Name.name, nil ].sample,
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
