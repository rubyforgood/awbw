# Home page content seeds (dev-only) - run on their own via `rake db:seed:home_page_content`,
# or as part of `rake db:seed:dev`. Covers the editorial content surfaced on the home page:
# CommunityNews, StoryIdeas, WorkshopIdeas, WorkshopVariationIdeas (and links some variations
# to them), and Stories. Related records (organizations, workshops, people) are looked up when present.

# Faker is installed but not auto-required on staging, where the app runs as
# RAILS_ENV=production and Bundler.require only loads the production group.
require "faker"

puts "Creating CommunityNews…"
[
  "Workshop Spotlight: Building Confidence Through Art",
  "New Facilitator Training Resources Released",
  "Creative Healing Story of the Month",
  "Leader Highlight: Supporting Survivors with Compassion",
  "New Workshop Series Launching This Spring",
  "Art-Based Tools for Emotional Safety",
  "Celebrating Community Voices",
  "Partner Site Success Story",
  "New Resources Added to the Library",
  "How Creativity Builds Connection"
].each_with_index do |title, i|
  visibility = if i < 3
    { published: true, featured: true }
  elsif i < 6
    { published: true, publicly_visible: true, publicly_featured: true }
  else
    { published: [ true, true, false ].sample, featured: [ true, false ].sample,
      publicly_visible: [ true, false ].sample, publicly_featured: [ true, false ].sample }
  end

  body_content = Faker::Lorem.paragraph(sentence_count: 6)
  CommunityNews.where(title: title)
               .first_or_create!(
                  body: body_content,
                  rhino_body: "<p>#{body_content}</p>",
                  author_id: [ Person.all.sample, nil, nil ].sample&.id,
                  created_by_id: User.first&.id,
                  updated_by_id: User.first&.id,
                  organization_id: Organization.all.sample&.id,
                  windows_type_id: WindowsType.all.sample&.id,
                  created_at: Time.current - rand(1..60).days,
                  updated_at: Time.current - rand(1..30).days,
                  **visibility
                )
end

puts "Creating StoryIdeas…"
10.times do |i|
  body_content = Faker::Lorem.paragraph(sentence_count: 10)
  StoryIdea.create!(
    body: body_content,
    rhino_body: "<p>#{body_content}</p>",
    author_credit_preference: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES.sample,
    permission_given: true,
    external_workshop_title: [ nil, nil, "Community Art Night", "Healing Arts Circle" ].sample,
    organization_id: Organization.all.sample&.id,
    workshop_id: Workshop.all.sample&.id,
    windows_type_id: WindowsType.all.sample&.id,
    youtube_url: [ nil, nil, "https://youtube.com/watch?v=dQw4w9WgXcQ",
                  "https://youtube.com/watch?v=abcd1234xyz" ].sample,
    created_by_id: User.first&.id,
    updated_by_id: User.first&.id,
    created_at: Time.current - rand(1..90).days,
    updated_at: Time.current - rand(1..40).days
  )
end

puts "Creating WorkshopIdeas…"
[
  "Creative Expression Through Collage",
  "Mindful Drawing for Healing",
  "Empowerment Through Mixed Media"
].each do |title|
  WorkshopIdea.where(title: title).first_or_create!(
    author_credit_preference: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES.sample,
    windows_type_id: WindowsType.all.sample&.id,
    created_by_id: User.first&.id,
    updated_by_id: User.first&.id,
    created_at: Time.current - rand(1..90).days,
    updated_at: Time.current - rand(1..40).days
  )
end

puts "Creating WorkshopVariationIdeas…"
[
  "Art Journaling Variation",
  "Group Mural Adaptation",
  "Outdoor Collage Variation"
].each do |name|
  workshop = Workshop.all.sample
  next unless workshop

  WorkshopVariationIdea.where(name: name, workshop_id: workshop.id).first_or_create!(
    rhino_body: "<p>#{Faker::Lorem.paragraph(sentence_count: 6)}</p>",
    permission_given: true,
    author_credit_preference: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES.sample,
    organization_id: Organization.all.sample&.id,
    windows_type_id: WindowsType.all.sample&.id,
    created_by_id: User.first&.id,
    updated_by_id: User.first&.id,
    created_at: Time.current - rand(1..90).days,
    updated_at: Time.current - rand(1..40).days
  )
end

puts "Linking some WorkshopVariations to WorkshopVariationIdeas…"
WorkshopVariationIdea.all.sample(2).each_with_index do |idea, i|
  # Only link variations that pass validation — skips any legacy/invalid rows
  # so update! doesn't fail on records this seed didn't create.
  variation = WorkshopVariation.where(workshop_variation_idea_id: nil).find(&:valid?)
  next unless variation

  variation.update!(workshop_variation_idea_id: idea.id, published: i > 0)
end

puts "Creating Stories…"
# Deterministic so the Story Share portal demos well: every story is published +
# publicly visible, the first five are publicly featured, sectors/audiences are
# tagged (with ≥3 public stories in each featured sector), a few are facilitator
# spotlights, and most get a primary image (last two exercise the fallback).
story_seeds = [
  { title: "Healing Through Art: A Survivor's Journey", sectors: [ "Domestic Violence" ], audiences: [ "Adults" ] },
  { title: "Finding Strength in Creativity", sectors: [ "Domestic Violence", "Self-Care/Personal Growth" ], audiences: [ "Adults", "Families" ] },
  { title: "A Workshop Moment That Changed Everything", sectors: [ "Racial/Social Justice" ], audiences: [ "Teens" ] },
  { title: "From Silence to Expression", sectors: [ "Domestic Violence" ], audiences: [ "Adults" ] },
  { title: "Rediscovering Self-Worth Through Art", sectors: [ "Self-Care/Personal Growth", "Mental Health" ], audiences: [ "Adults" ], youtube: true },
  { title: "Painting the Path to Healing", sectors: [ "Racial/Social Justice", "Grief/Loss" ], audiences: [ "Community" ] },
  { title: "A Child's Story of Safety and Hope", sectors: [ "Domestic Violence" ], audiences: [ "Children" ], spotlight: true },
  { title: "Community Coming Together Through Workshops", sectors: [ "Racial/Social Justice" ], audiences: [ "Community" ] },
  { title: "Leadership in Action: A Facilitator's Story", sectors: [ "Mental Health" ], audiences: [ "Colleagues" ], spotlight: true },
  { title: "When Art Opens a Door", sectors: [ "Grief/Loss" ], audiences: [ "Self" ], spotlight: true }
]
story_images = %w[who-we-are-grid.jpg what-we-do.jpg ways-to-help.jpg our-next-chapter.jpg workshop_default.jpg]

story_seeds.each_with_index do |seed, i|
  body_content = Faker::Lorem.paragraph(sentence_count: 10)
  story = Story.where(title: seed[:title]).first_or_create!(
    body: body_content,
    rhino_body: "<p>#{body_content}</p>",
    permission_given: true,
    organization_id: Organization.all.sample&.id,
    workshop_id: [ nil, Workshop.all.sample&.id ].sample,
    windows_type_id: WindowsType.all.sample&.id,
    spotlighted_facilitator_id: (Person.all.sample&.id if seed[:spotlight]),
    youtube_url: (seed[:youtube] ? "https://youtube.com/watch?v=dQw4w9WgXcQ" : nil),
    created_by_id: User.first&.id,
    updated_by_id: User.first&.id,
    created_at: Time.current - (i * 7).days,
    updated_at: Time.current - (i * 3).days,
    published: true, publicly_visible: true, publicly_featured: i < 5, featured: i < 5
  )

  # Force the demo-critical fields even on stories from an earlier seed run
  # (first_or_create! only assigns them on insert).
  story.update!(
    published: true, publicly_visible: true, publicly_featured: i < 5, featured: i < 5,
    spotlighted_facilitator_id: story.spotlighted_facilitator_id || (Person.all.sample&.id if seed[:spotlight]),
    youtube_url: seed[:youtube] ? "https://youtube.com/watch?v=dQw4w9WgXcQ" : story.youtube_url
  )

  seed[:sectors].each do |name|
    sector = Sector.find_by(name: name) or next
    story.sectorable_items.find_or_create_by!(sector: sector)
  end
  seed[:audiences].each do |name|
    category = Category.where("LOWER(name) = LOWER(?)", name).first or next
    story.categorizable_items.find_or_create_by!(category: category)
  end

  next if i >= story_images.length # last two stay image-less on purpose
  asset = story.primary_asset
  next if asset&.file&.attached?

  image_path = Rails.root.join("app/assets/images", story_images[i])
  next unless File.exist?(image_path)
  asset ||= story.assets.build(type: "PrimaryAsset")
  asset.file.attach(io: File.open(image_path), filename: story_images[i], content_type: "image/jpeg")
  asset.save!
end
