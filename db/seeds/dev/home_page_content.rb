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
[
  "Healing Through Art: A Survivor's Journey",
  "Finding Strength in Creativity",
  "A Workshop Moment That Changed Everything",
  "From Silence to Expression",
  "Rediscovering Self-Worth Through Art",
  "Painting the Path to Healing",
  "A Child's Story of Safety and Hope",
  "Community Coming Together Through Workshops",
  "Leadership in Action: A Facilitator's Story",
  "When Art Opens a Door"
].each_with_index do |title, i|
  visibility = if i < 3
    { published: true, featured: true }
  elsif i < 6
    { published: true, publicly_visible: true, publicly_featured: true }
  else
    { published: [ true, true, false ].sample, featured: [ true, false ].sample,
      publicly_visible: [ true, false ].sample, publicly_featured: [ true, false ].sample }
  end

  body_content = Faker::Lorem.paragraph(sentence_count: 10)
  Story.where(title: title)
       .first_or_create!(
          body: body_content,
          rhino_body: "<p>#{body_content}</p>",
          permission_given: true,
          external_workshop_title: [ nil, nil, nil, nil, nil, nil, "Community Art Night", "Healing Arts Circle" ].sample,
          organization_id: Organization.all.sample&.id,
          workshop_id: [ nil, Workshop.all.sample&.id ].sample,
          story_idea_id: [ nil, nil, nil, nil, nil, nil, nil, nil, StoryIdea.all.sample&.id ].sample,
          windows_type_id: WindowsType.all.sample&.id,
          spotlighted_facilitator_id: [ nil, nil, nil, nil, Person.all.sample&.id ].sample,
          youtube_url: [
            nil,
            nil,
            "https://youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtube.com/watch?v=abcd1234xyz"
          ].sample,
          created_by_id: User.first&.id,
          updated_by_id: User.first&.id,
          created_at: Time.current - rand(1..90).days,
          updated_at: Time.current - rand(1..40).days,
          **visibility
       )
end
