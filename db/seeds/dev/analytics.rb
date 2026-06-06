# Analytics seeds (dev-only) - run on their own via `rake db:seed:analytics`, or as part
# of `rake db:seed:dev`. Generates Ahoy visits and events that populate the analytics
# dashboards. Most useful after the content/event seeds have run; degrades gracefully
# when those records are absent.

# ─── Ahoy visits & events (analytics charts) ───────────────────────────
if Ahoy::Visit.any?
  puts "Skipping Ahoy seed data (#{Ahoy::Visit.count} visits already exist)"
else
  puts "Creating Ahoy visits and events for analytics charts…"

  all_non_staff = User.where(super_user: false).where.not(confirmed_at: nil).to_a
  ahoy_users = (all_non_staff.sample([ all_non_staff.size, 8 ].min) + [ nil ]).compact

  cities = [ "Los Angeles", "San Diego", "Portland", "Seattle", "Denver" ]
  browsers = %w[Chrome Safari Firefox Edge]
  devices = %w[Desktop Mobile Tablet]

  # Create visits spread over the past month, with some users browsing more than others
  ahoy_visits = []
  # Give each visit-user a weight so some browse heavily, others lightly
  visit_user_weights = ahoy_users.each_with_object({}) do |user, h|
    h[user] = rand(1..5)
  end
  visit_user_weights[nil] = 2 # anonymous visitors

  30.times do |day_offset|
    rand(3..6).times do
      user = visit_user_weights.max_by { |_u, w| rand**(1.0 / w) }.first
      visit = Ahoy::Visit.create!(
        visit_token: SecureRandom.uuid,
        visitor_token: SecureRandom.uuid,
        user: user,
        started_at: (30 - day_offset).days.ago + rand(0..23).hours,
        browser: browsers.sample,
        device_type: devices.sample,
        city: cities.sample,
        country: "US",
        landing_page: %w[/workshops /resources /stories /].sample
      )
      ahoy_visits << visit
    end
  end

  # Gather real records for view/print events
  view_targets = {
    "workshop" => Workshop.published.limit(6).to_a,
    "resource" => Resource.published.limit(6).to_a,
    "person" => Person.limit(4).to_a,
    "story" => Story.published.limit(4).to_a,
    "event" => Event.limit(3).to_a,
    "community_news" => CommunityNews.published.limit(3).to_a,
    "workshop_variation" => WorkshopVariation.published.limit(3).to_a,
    "video_recording" => VideoRecording.limit(3).to_a
  }.reject { |_, v| v.empty? }

  # ── view.* events (populates "Content Types People View Most" pie chart) ──
  # Generate enough view events across varied users so engagement differs from logins
  view_targets.each do |resource_name, records|
    weight = resource_name == "workshop" ? 20 : (resource_name == "resource" ? 12 : 6)
    weight.times do
      record = records.sample
      visit = ahoy_visits.sample
      Ahoy::Event.create!(
        visit: visit,
        user: visit.user,
        name: "view.#{resource_name}",
        resource_type: record.class.name,
        resource_id: record.id,
        properties: { resource_type: record.class.name, resource_id: record.id, resource_title: record.try(:title) || record.try(:name) },
        time: visit.started_at + rand(1..300).seconds
      )
    end
  end

  # ── print.* events ──
  %w[workshop resource story community_news].each do |resource_name|
    next unless view_targets[resource_name]&.any?

    rand(4..8).times do
      record = view_targets[resource_name].sample
      visit = ahoy_visits.sample
      Ahoy::Event.create!(
        visit: visit,
        user: visit.user,
        name: "print.#{resource_name}",
        resource_type: record.class.name,
        resource_id: record.id,
        properties: { resource_type: record.class.name, resource_id: record.id, resource_title: record.try(:title) || record.try(:name) },
        time: visit.started_at + rand(60..600).seconds
      )
    end
  end

  # ── download.resource events ──
  if view_targets["resource"]&.any?
    3.times do
      record = view_targets["resource"].sample
      visit = ahoy_visits.sample
      Ahoy::Event.create!(
        visit: visit,
        user: visit.user,
        name: "download.resource",
        resource_type: "Resource",
        resource_id: record.id,
        properties: { resource_type: "Resource", resource_id: record.id, resource_title: record.try(:title) },
        time: visit.started_at + rand(60..600).seconds
      )
    end
  end

  # ── filter.workshops / search.workshops events (populates category/sector/windows type charts) ──
  seed_categories = Category.joins(:category_type).where(published: true).limit(15).to_a
  seed_sectors = Sector.where(published: true).limit(10).to_a
  seed_windows_types = WindowsType.all.to_a

  search_titles = [ "self care", "container of feelings", "self-care", "resilience", "touchstones",
                    "domestic violence", "grief", "personal needs flower", "butterfly", "may you be" ]
  search_authors = [ "fabian", "aaron", "power and control wheel", "aaron mason", "Janet Hughes" ]
  search_full_texts = [ "anxiety", "we rise", "luck", "collage", "mental wellness",
                        "mental well-being", "friendship", "transforming", "north star" ]

  # Filter events with categories, sectors, and windows types
  20.times do
    visit = ahoy_visits.sample
    cats = seed_categories.sample(rand(1..3)).map { |c| { id: c.id, name: c.name, type: c.category_type&.name } }
    secs = seed_sectors.sample(rand(1..2)).map { |s| { id: s.id, name: s.name } }
    wts = seed_windows_types.sample(rand(1..2)).map(&:id)

    props = {
      resource_type: "Workshop",
      result_count: rand(3..40),
      filters: { categories: cats, sectors: secs, windows_types: wts }
    }

    Ahoy::Event.create!(
      visit: visit,
      user: visit.user,
      name: "filter.workshops",
      properties: props,
      time: visit.started_at + rand(10..120).seconds
    )
  end

  # Search events with keywords AND filters
  15.times do
    visit = ahoy_visits.sample
    cats = seed_categories.sample(rand(1..2)).map { |c| { id: c.id, name: c.name, type: c.category_type&.name } }
    secs = seed_sectors.sample(rand(1..2)).map { |s| { id: s.id, name: s.name } }
    wts = seed_windows_types.sample(rand(1..2)).map(&:id)

    props = {
      resource_type: "Workshop",
      result_count: rand(1..20),
      keywords: {
        title: search_titles.sample,
        author: search_authors.sample,
        full_text: search_full_texts.sample
      },
      filters: { categories: cats, sectors: secs, windows_types: wts }
    }

    Ahoy::Event.create!(
      visit: visit,
      user: visit.user,
      name: "search.workshops",
      properties: props,
      time: visit.started_at + rand(10..120).seconds
    )
  end

  # ── search_zero.workshops events (populates "No Results" chart) ──
  zero_queries = [ "watercolor techniques for teens", "music therapy", "yoga breathing",
                   "sand tray", "outdoor art", "digital collage", "puppet making 101",
                   "grief journaling advanced" ]
  zero_queries.each do |query|
    visit = ahoy_visits.sample
    rand(1..3).times do
      Ahoy::Event.create!(
        visit: visit,
        user: visit.user,
        name: "search_zero.workshops",
        properties: {
          resource_type: "Workshop",
          result_count: 0,
          query: query,
          keywords: { full_text: query }
        },
        time: visit.started_at + rand(10..300).seconds
      )
    end
  end

  # ── search.taggings events (supplements tagging charts) ──
  50.times do
    visit = ahoy_visits.sample
    Ahoy::Event.create!(
      visit: visit,
      user: visit.user,
      name: "search.taggings",
      properties: {
        sectors: seed_sectors.sample(rand(1..3)).map(&:name),
        categories: seed_categories.sample(rand(1..3)).map(&:name),
        page_result_count: rand(5..30)
      },
      time: visit.started_at + rand(10..300).seconds
    )
  end

  # ── filter.resources / search.resources events ──
  resource_keywords = [ "art supplies guide", "facilitator handbook", "trauma informed", "group activity",
                        "healing through art", "coloring pages", "workshop template" ]
  resource_kinds = %w[pdf video link document]

  5.times do
    visit = ahoy_visits.sample
    Ahoy::Event.create!(
      visit: visit,
      user: visit.user,
      name: "filter.resources",
      properties: { resource_type: "Resource", result_count: rand(2..15), filters: { kind: resource_kinds.sample } },
      time: visit.started_at + rand(10..120).seconds
    )
  end

  5.times do
    visit = ahoy_visits.sample
    Ahoy::Event.create!(
      visit: visit,
      user: visit.user,
      name: "search.resources",
      properties: { resource_type: "Resource", result_count: rand(1..10), keywords: { full_text: resource_keywords.sample } },
      time: visit.started_at + rand(10..120).seconds
    )
  end

  # ── create.* events (populates "Content Creation Velocity" chart) ──
  if view_targets["workshop"]&.any?
    %w[workshop_idea story_idea workshop_variation_idea workshop_log quote bookmark].each do |model_name|
      klass = model_name.classify.safe_constantize
      next unless klass

      records = klass.limit(3).to_a
      next if records.empty?

      records.each do |record|
        visit = ahoy_visits.sample
        Ahoy::Event.create!(
          visit: visit,
          user: visit.user,
          name: "create.#{model_name}",
          resource_type: record.class.name,
          resource_id: record.id,
          properties: { resource_type: record.class.name, resource_id: record.id, resource_title: record.try(:title) || record.try(:name) },
          time: visit.started_at + rand(60..600).seconds
        )
      end
    end
  end

  # ── auth.login events (populates "Portal usage" charts) ──
  # Simulate realistic login patterns: some users log in daily, others weekly
  all_seeded_users = User.where(super_user: false).where.not(confirmed_at: nil).to_a
  if all_seeded_users.any?
    # Assign each user a login frequency: heavy, moderate, or light
    all_seeded_users.each do |user|
      frequency = %i[heavy moderate light light light].sample
      login_days = case frequency
      when :heavy   then (0..89).to_a.sample(rand(40..70))
      when :moderate then (0..89).to_a.sample(rand(12..25))
      when :light    then (0..89).to_a.sample(rand(2..6))
      end

      login_days.sort.each do |day_offset|
        started = day_offset.days.ago + rand(6..22).hours
        visit = Ahoy::Visit.create!(
          visit_token: SecureRandom.uuid,
          visitor_token: SecureRandom.uuid,
          user: user,
          started_at: started,
          browser: browsers.sample,
          device_type: devices.sample,
          city: cities.sample,
          country: "US",
          landing_page: "/"
        )
        ahoy_visits << visit

        Ahoy::Event.create!(
          visit: visit,
          user: user,
          name: "auth.login",
          properties: { sign_in_count: rand(1..200) },
          time: started + rand(0..30).seconds
        )
      end
    end
  end

  puts "  Created #{Ahoy::Visit.count} visits, #{Ahoy::Event.count} events"
end
