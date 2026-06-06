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
