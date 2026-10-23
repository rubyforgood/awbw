require "rails_helper"

RSpec.describe "/story_share", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let(:windows_type) { create(:windows_type) }
  let(:workshop)     { create(:workshop) }
  let(:organization) { create(:organization) }

  let(:base_attributes) do
    {
      title: "Story #{SecureRandom.hex(4)}",
      rhino_body: "<p>Once upon a time...</p>",
      windows_type_id: windows_type.id,
      story_workshops_attributes: [ { workshop_id: workshop.id } ],
      organization_id: organization.id,
      created_by_id: admin.id,
      updated_by_id: admin.id
    }
  end

  let!(:published_story) do
    Story.create!(base_attributes.merge(
      title: "Story #{SecureRandom.hex(4)}",
      published: true
    ))
  end

  let!(:public_story) do
    create(:story, :published, :publicly_visible)
  end

  let!(:private_story) do
    Story.create!(base_attributes.merge(
      title: "Story #{SecureRandom.hex(4)}",
      published: false,
      publicly_visible: false
    ))
  end

  # Published + publicly visible, but funder-only — never belongs on the Story
  # Share showcase, for any audience.
  let!(:funder_only_story) do
    create(:story, :published, :publicly_visible, :funder_only, title: "Funder Only #{SecureRandom.hex(4)}")
  end

  # ==========================================================
  # ADMIN
  # ==========================================================
  describe "as admin" do
    before { sign_in admin }

    describe "GET /index" do
      it "returns success" do
        get story_shares_path
        expect(response).to have_http_status(:ok)
      end

      it "never lists funder-only stories, even for admins" do
        get story_shares_path(query: "Funder")
        expect(response.body).not_to include(funder_only_story.title)
      end
    end

    describe "GET /show" do
      it "leads the tag chips with the starred primary sector and audience" do
        population = create(:category_type, :published, name: CategoriesTaggable::STORY_POPULATION_CATEGORY_TYPE)
        public_story.sectorable_items.create!(sector: create(:sector, :published, name: "Arts"))
        public_story.sectorable_items.create!(sector: create(:sector, :published, name: "Zoo"), is_primary: true)
        public_story.categorizable_items.create!(category: create(:category, :published, name: "Adults", category_type: population))
        public_story.categorizable_items.create!(category: create(:category, :published, name: "Teens", category_type: population), is_primary: true)

        get story_share_url(public_story)

        page = Capybara.string(response.body)
        expect(page).to have_css("a[title='Primary sector'] i.fa-star")
        expect(page).to have_css("a[title='Primary category'] i.fa-star")
        chips = page.find("strong", text: "Tags:").find(:xpath, "..").all("a").map { |chip| chip.text.strip }
        expect(chips).to eq([ "Zoo", "Arts", "Teens", "Adults" ])
      end

      it "shows only the starred primary sector and story population on picture cards" do
        population = create(:category_type, :published, name: CategoriesTaggable::STORY_POPULATION_CATEGORY_TYPE)
        arts = create(:sector, :published, name: "Arts")
        public_story.sectorable_items.create!(sector: arts)
        public_story.sectorable_items.create!(sector: create(:sector, :published, name: "Zoo"), is_primary: true)
        public_story.categorizable_items.create!(category: create(:category, :published, name: "Teens", category_type: population), is_primary: true)

        get story_shares_url(sector_names_all: "Zoo")

        page = Capybara.string(response.body)
        pills = page.all("span[title^='Primary']").map { |pill| pill.text.strip }
        expect(pills).to eq([ "Zoo", "Teens" ])
        expect(page).to have_no_css("span[title^='Primary'] i.fa-star")
      end

      it "falls back to the first sector on picture cards when none is starred" do
        arts = create(:sector, :published, name: "Arts")
        public_story.sectorable_items.create!(sector: arts)

        get story_shares_url(page: 1)

        page = Capybara.string(response.body)
        expect(page).to have_css("span.rounded-full.uppercase", text: "Arts")
        expect(page).to have_no_css("span[title^='Primary']")
      end

      it "can view any story" do
        get story_share_path(private_story)
        expect(response).to have_http_status(:ok)
      end

      it "cannot view a funder-only story on the showcase" do
        get story_share_path(funder_only_story)
        expect(response).not_to have_http_status(:ok)
      end
    end
  end

  # ==========================================================
  # REGULAR USER (authenticated, not admin)
  # ==========================================================
  describe "as regular_user" do
    before { sign_in regular_user }

    describe "GET /index" do
      it "returns success" do
        get story_shares_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /show" do
      it "can view published story" do
        get story_share_path(published_story)
        expect(response).to have_http_status(:ok)
      end

      it "cannot view private story" do
        get story_share_path(private_story)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ==========================================================
  # GUEST (not authenticated)
  # ==========================================================
  describe "as guest" do
    describe "GET /index" do
      it "returns success" do
        get story_shares_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /show" do
      it "can view publicly visible story" do
        get story_share_path(public_story)
        expect(response).to have_http_status(:ok)
      end

      it "cannot view published-only story" do
        get story_share_path(published_story)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ==========================================================
  # NAVBAR
  # ==========================================================
  describe "portal navbar" do
    let!(:featured_sector) { create(:sector, :published, name: "Domestic Violence", story_share_position: 1) }
    let!(:audience) do
      population = create(:category_type, name: "StoryPopulation")
      create(:category, :published, name: "Teens", category_type: population, story_share_position: 1)
    end

    it "renders working search, canonical sector/audience links, and no dead links" do
      get story_shares_path

      expect(response.body).to include('name="query"')
      expect(response.body).to include("sector_names_all=Domestic")
      expect(response.body).to include("category_names_all=Teens")
      expect(response.body).not_to include('href="#"')
    end

    it "has no Facilitator Spotlights link or home box" do
      create(:story, :published, :publicly_visible, spotlighted_facilitator: create(:person))

      get story_shares_path

      expect(response.body).not_to include("Facilitator Spotlights")
    end

    it "shows featured age ranges, then story populations, as one audience row" do
      age_range = create(:category_type, name: "AgeRange")
      create(:category, :published, name: "Children", category_type: age_range, story_share_position: 1)
      create(:category, :published, name: "Clay", story_share_position: 1)

      get story_shares_path

      expect(response.body).to include("category_names_all=Children")
      expect(response.body).not_to include("category_names_all=Clay")
      expect(response.body.index("category_names_all=Children")).to be < response.body.index("category_names_all=Teens")
    end

    it "points the footer Contact us link at the in-app portal contact page" do
      get story_shares_path

      expect(response.body).to include(contact_us_path(from: "story_share"))
    end
  end

  # ==========================================================
  # LANDING PAGE — audience (age-group) sections
  # ==========================================================
  describe "landing-page audience sections" do
    let!(:age_range) { create(:category_type, name: "AgeRange") }

    def tag_story(category, title, is_primary: true)
      story = create(:story, :published, :publicly_visible, title: title)
      story.categorizable_items.create!(category: category, is_primary: is_primary)
      story
    end

    it "renders a section for each featured audience toggled on, in nav order" do
      children = create(:category, :published, name: "Children", category_type: age_range, story_share_position: 1)
      adults   = create(:category, :published, name: "Adults", category_type: age_range, story_share_position: 2)
      tag_story(children, "A kids workshop story")
      tag_story(adults, "An adult survivor story")

      get story_shares_path

      expect(response.body).to include("A kids workshop story")
      expect(response.body).to include("More Children stories...")
      expect(response.body).to include("category_names_all=Children")
      expect(response.body).to include("An adult survivor story")
      expect(response.body).to include("More Adults stories...")
      expect(response.body.index("More Children stories...")).to be < response.body.index("More Adults stories...")
    end

    it "omits a featured audience whose home-section toggle is off" do
      adults = create(:category, :published, name: "Adults", category_type: age_range,
                                             story_share_position: 1, story_share_home_section: false)
      tag_story(adults, "An adult survivor story")

      get story_shares_path

      expect(response.body).not_to include("More Adults stories...")
    end

    it "omits an audience that is not featured in the nav even when toggled on" do
      children = create(:category, :published, name: "Children", category_type: age_range,
                                               story_share_position: nil, story_share_home_section: true)
      tag_story(children, "A kids workshop story")

      get story_shares_path

      expect(response.body).not_to include("More Children stories...")
    end

    it "lists only stories starring the audience as primary" do
      teens = create(:category, :published, name: "Teens", category_type: age_range, story_share_position: 1)
      tag_story(teens, "A teen-first story")
      tag_story(teens, "A story only touching on teens", is_primary: false)

      get story_shares_path

      section = Capybara.string(response.body).find("h2", exact_text: "Teens").find(:xpath, "..")
      expect(section).to have_text("A teen-first story")
      expect(section).to have_no_text("A story only touching on teens")
    end
  end

  # ==========================================================
  # LANDING PAGE — sector sections
  # ==========================================================
  describe "landing-page sector sections" do
    def tag_sector_story(sector, title, is_primary: true)
      story = create(:story, :published, :publicly_visible, title: title)
      story.sectorable_items.create!(sector: sector, is_primary: is_primary)
      story
    end

    it "renders a section for a featured sector toggled on" do
      sector = create(:sector, :published, name: "Homelessness", story_share_position: 1)
      tag_sector_story(sector, "A story about housing")

      get story_shares_path

      expect(response.body).to include("A story about housing")
      expect(response.body).to include("More Homelessness stories...")
    end

    it "omits a featured sector whose home-section toggle is off" do
      sector = create(:sector, :published, name: "Homelessness",
                                           story_share_position: 1, story_share_home_section: false)
      tag_sector_story(sector, "A story about housing")

      get story_shares_path

      expect(response.body).not_to include("More Homelessness stories...")
    end

    it "lists only stories starring the sector as primary" do
      sector = create(:sector, :published, name: "Homelessness", story_share_position: 1)
      tag_sector_story(sector, "A story about housing")
      tag_sector_story(sector, "A story only touching on housing", is_primary: false)

      get story_shares_path

      section = Capybara.string(response.body).find("h2", exact_text: "Homelessness").find(:xpath, "..")
      expect(section).to have_text("A story about housing")
      expect(section).to have_no_text("A story only touching on housing")
    end
  end

  # ==========================================================
  # BROWSING / FILTERING (public)
  # ==========================================================
  describe "browsing filtered results" do
    def tag_sector(story, name, is_primary: true)
      sector = Sector.find_by(name: name) || create(:sector, :published, name: name)
      story.sectorable_items.create!(sector: sector, is_primary: is_primary)
      sector
    end

    def highlighted_titles
      page = Capybara.string(response.body)
      page.all("div.mb-12 h2, article h3").map { |node| node.text.strip }
    end

    def listed_titles
      Capybara.string(response.body).all("div.space-y-16 h2").map { |node| node.text.strip }
    end

    let!(:dv_story) do
      create(:story, :published, :publicly_visible, title: "A DV survivor story").tap { |s| tag_sector(s, "Domestic Violence") }
    end
    let!(:other_story) do
      create(:story, :published, :publicly_visible, title: "An unrelated story").tap { |s| tag_sector(s, "Mental Health") }
    end

    it "shows only stories tagged with the requested sector" do
      get story_shares_path(sector_names_all: "Domestic Violence")
      expect(response.body).to include("A DV survivor story")
      expect(response.body).not_to include("An unrelated story")
    end

    it "lists stories carrying the sector as a secondary tag below the hero and cards, never in them" do
      2.times do |i|
        story = create(:story, :published, :publicly_visible, :publicly_featured, title: "A secondary DV story #{i}")
        tag_sector(story, "Mental Health")
        tag_sector(story, "Domestic Violence", is_primary: false)
      end

      get story_shares_path(sector_names_all: "Domestic Violence")
      expect(highlighted_titles).to eq([ "A DV survivor story" ])
      expect(listed_titles).to contain_exactly("A secondary DV story 0", "A secondary DV story 1")
      expect(response.body).to include("3 stories")
    end

    it "renders an empty state when a sector has no matching stories" do
      get story_shares_path(sector_names_all: "Homelessness")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No stories found.")
    end

    it "filters by keyword query" do
      create(:story, :published, :publicly_visible, title: "Watercolor healing journey")
      get story_shares_path(query: "Watercolor")
      expect(response.body).to include("Watercolor healing journey")
      expect(response.body).not_to include("An unrelated story")
    end

    it "filters by audience category" do
      story_population = create(:category_type, name: "StoryPopulation")
      teens = create(:category, :published, name: "Teens", category_type: story_population)
      teen_story = create(:story, :published, :publicly_visible, title: "A teen art story")
      teen_story.categorizable_items.create!(category: teens, is_primary: true)

      get story_shares_path(category_names_all: "Teens")
      expect(response.body).to include("A teen art story")
      expect(response.body).not_to include("An unrelated story")
    end

    it "keeps an audience's carousel and cards to stories starring it as primary, listing the rest below" do
      age_range = create(:category_type, name: "AgeRange")
      teens = create(:category, :published, name: "Teens", category_type: age_range)
      adults = create(:category, :published, name: "Adults", category_type: age_range)
      create(:story, :published, :publicly_visible, title: "A teen art story")
        .categorizable_items.create!(category: teens, is_primary: true)
      create(:story, :published, :publicly_visible, :publicly_featured, title: "An adult story with teens too").tap do |story|
        story.categorizable_items.create!(category: adults, is_primary: true)
        story.categorizable_items.create!(category: teens)
      end

      get story_shares_path(category_names_all: "Teens")
      expect(highlighted_titles).to eq([ "A teen art story" ])
      expect(listed_titles).to eq([ "An adult story with teens too" ])
    end

    it "does not leak non-public stories to guests when browsing" do
      create(:story, :published, title: "A published-only secret", publicly_visible: false).tap { |s| tag_sector(s, "Domestic Violence") }
      get story_shares_path(sector_names_all: "Domestic Violence")
      expect(response.body).not_to include("A published-only secret")
    end

    it "anchors pagination links to the first story's title so they skip the top hero" do
      6.times { |i| create(:story, :published, :publicly_visible, title: "DV story #{i}").tap { |s| tag_sector(s, "Domestic Violence") } }
      get story_shares_path(sector_names_all: "Domestic Violence", number_of_items_per_page: 2)
      expect(response.body).to include('id="stories"')
      expect(response.body).to match(/href="[^"]*page=2[^"]*#stories"/)
    end

    it "leads a sector page with the publicly featured story, even if older" do
      newer = create(:story, :published, :publicly_visible, title: "Plain newer DV story", created_at: 1.day.ago)
      tag_sector(newer, "Domestic Violence")
      featured = create(:story, :published, :publicly_visible, :publicly_featured, title: "Featured older DV story", created_at: 10.days.ago)
      tag_sector(featured, "Domestic Violence")

      get story_shares_path(sector_names_all: "Domestic Violence")
      expect(response.body.index("Featured older DV story")).to be < response.body.index("Plain newer DV story")
    end

    it "orders the cards below the sector hero newest-first, without repeating the hero" do
      lead = create(:story, :published, :publicly_visible, :publicly_featured, title: "Featured lead DV story", created_at: 10.days.ago)
      older_featured = create(:story, :published, :publicly_visible, :publicly_featured, title: "Featured older DV story", created_at: 20.days.ago)
      newest = create(:story, :published, :publicly_visible, title: "Plain newest DV story", created_at: 1.day.ago)
      [ lead, older_featured, newest ].each { |story| tag_sector(story, "Domestic Violence") }

      get story_shares_path(sector_names_all: "Domestic Violence")
      body = response.body
      expect(body.index("Featured lead DV story")).to be < body.index("Plain newest DV story")
      expect(body.index("Plain newest DV story")).to be < body.index("Featured older DV story")
      expect(body.scan(%r{href="#{story_share_path(lead)}"}).size).to eq(1)
    end

    it "shows the hero only on the first browse page" do
      create(:story, :published, :publicly_visible, :publicly_featured, title: "Featured lead housing story", created_at: 10.days.ago)
        .tap { |story| tag_sector(story, "Housing") }
      (1..5).each do |days|
        create(:story, :published, :publicly_visible, title: "Plain housing story #{days}", created_at: days.days.ago)
          .tap { |story| tag_sector(story, "Housing") }
      end

      get story_shares_path(sector_names_all: "Housing", number_of_items_per_page: 1, page: 2)
      expect(listed_titles).to eq([ "Plain housing story 5" ])
      expect(highlighted_titles).to be_empty
      expect(response.body).not_to include("Featured lead housing story")
    end

    it "aggregates non-featured sectors on the additional focus areas page" do
      featured = create(:sector, :published, name: "Featured Sector", story_share_position: 1)
      extra = create(:sector, :published, name: "Homelessness")
      create(:story, :published, :publicly_visible, title: "A featured-only story").tap { |s| s.sectorable_items.create!(sector: featured, is_primary: true) }
      create(:story, :published, :publicly_visible, title: "An additional-area story").tap { |s| s.sectorable_items.create!(sector: extra, is_primary: true) }

      get story_shares_path(additional_focus_areas: true)
      expect(response.body).to include("An additional-area story")
      expect(response.body).not_to include("A featured-only story")
    end

    it "features additional focus areas by primary sector, listing secondary matches below" do
      featured = create(:sector, :published, name: "Featured Sector", story_share_position: 1)
      extra = create(:sector, :published, name: "Homelessness")
      create(:story, :published, :publicly_visible, title: "A featured-first story").tap do |story|
        story.sectorable_items.create!(sector: featured, is_primary: true)
        story.sectorable_items.create!(sector: extra)
      end

      create(:story, :published, :publicly_visible, title: "A homelessness-first story")
        .tap { |story| story.sectorable_items.create!(sector: extra, is_primary: true) }

      get story_shares_path(additional_focus_areas: true)
      expect(highlighted_titles).to include("A homelessness-first story")
      expect(highlighted_titles).not_to include("A featured-first story")
      expect(listed_titles).to eq([ "A featured-first story" ])
    end

    it "gathers stories whose primary sector is featured past the nav's limit" do
      StorySharesController::FEATURED_SECTOR_LIMIT.times { |i| create(:sector, :published, name: "Nav sector #{i}", story_share_position: i + 1) }
      overflow = create(:sector, :published, name: "Overflow Sector", story_share_position: StorySharesController::FEATURED_SECTOR_LIMIT + 1)
      create(:story, :published, :publicly_visible, title: "An overflow-sector story").sectorable_items.create!(sector: overflow, is_primary: true)

      get story_shares_path(additional_focus_areas: true)
      expect(response.body).to include("An overflow-sector story")
    end

    it "gathers stories whose primary sector is Other, but not an unpublished one" do
      other = create(:sector, :published, name: Sector::OTHER_SECTOR_NAME)
      hidden = create(:sector, :unpublished, name: "Unpublished Sector")
      create(:story, :published, :publicly_visible, title: "An other-sector story").sectorable_items.create!(sector: other, is_primary: true)
      create(:story, :published, :publicly_visible, title: "An unpublished-sector story").sectorable_items.create!(sector: hidden, is_primary: true)

      get story_shares_path(additional_focus_areas: true)
      expect(response.body).to include("An other-sector story")
      expect(response.body).not_to include("An unpublished-sector story")
    end
  end

  # ==========================================================
  # HAND-PICKED HOME CAROUSEL
  # ==========================================================
  describe "hand-picked home carousel" do
    it "shows the hand-picked story on the Story Share home page" do
      create(:story, :published, :publicly_visible, title: "The hand-picked lead", story_share_carousel_position: 1)

      get story_shares_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The hand-picked lead")
    end

    it "still renders the carousel from featured/recent when nothing is hand-picked" do
      create(:story, :published, :publicly_visible, :publicly_featured, title: "A publicly featured story")

      get story_shares_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A publicly featured story")
    end
  end

  # ==========================================================
  # PORTRAIT IMAGES IN CAROUSELS
  # ==========================================================
  describe "portrait images in carousels" do
    def attach_image(story, asset_factory, width:, height:)
      asset = create(asset_factory, owner: story)
      asset.file.attach(ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("image"), filename: "art.png", content_type: "image/png",
        metadata: { width: width, height: height, analyzed: true }
      ))
    end

    def carousel_slide(story)
      Capybara.string(response.body).find(".swiper-slide", text: story.title)
    end

    it "shows a portrait story image whole over a blurred backdrop on the home carousel" do
      story = create(:story, :published, :publicly_visible, title: "Tall artwork", story_share_carousel_position: 1)
      attach_image(story, :primary_asset, width: 600, height: 900)

      get story_shares_path

      slide = carousel_slide(story)
      expect(slide).to have_css("img.object-contain[alt='Tall artwork']")
      expect(slide).to have_css("img.blur-2xl[aria-hidden='true']", visible: :all)
    end

    it "keeps cropping a landscape story image to fill the home carousel" do
      story = create(:story, :published, :publicly_visible, title: "Wide artwork", story_share_carousel_position: 1)
      attach_image(story, :primary_asset, width: 900, height: 600)

      get story_shares_path

      slide = carousel_slide(story)
      expect(slide).to have_css("img.object-cover[alt='Wide artwork']")
      expect(slide).to have_no_css("img.blur-2xl", visible: :all)
    end

    it "shows a portrait story image whole on a home topic card" do
      sector = create(:sector, :published, name: "Homelessness", story_share_position: 1)
      story = create(:story, :published, :publicly_visible, title: "Tall topic artwork")
      story.sectorable_items.create!(sector: sector, is_primary: true)
      attach_image(story, :primary_asset, width: 600, height: 900)

      get story_shares_path

      card = Capybara.string(response.body).find("article", text: "Tall topic artwork")
      expect(card).to have_css("img.object-contain[alt='Tall topic artwork']")
      expect(card).to have_css("img.blur-2xl[aria-hidden='true']", visible: :all)
    end

    it "shows a portrait story image whole on a browse card" do
      sector = create(:sector, :published, name: "Homelessness", story_share_position: 1)
      story = create(:story, :published, :publicly_visible, title: "Tall browse artwork", created_at: 2.days.ago)
      lead = create(:story, :published, :publicly_visible, title: "Newer lead story")
      [ story, lead ].each { |s| s.sectorable_items.create!(sector: sector, is_primary: true) }
      attach_image(story, :primary_asset, width: 600, height: 900)

      get story_shares_path(sector_names_all: "Homelessness")

      card = Capybara.string(response.body).find("article", text: "Tall browse artwork")
      expect(card).to have_css("img.object-contain[alt='Tall browse artwork']")
    end

    it "shows a portrait gallery image whole on the story page carousel" do
      story = create(:story, :published, :publicly_visible)
      attach_image(story, :gallery_asset, width: 600, height: 900)

      get story_share_path(story)

      slide = Capybara.string(response.body).find(".swiper-slide")
      expect(slide).to have_css("img.object-contain\\!")
      expect(slide).to have_css("img.blur-2xl[aria-hidden='true']", visible: :all)
    end
  end

  # ==========================================================
  # STANDARD IMAGE SHAPES
  # ==========================================================
  describe "standard image shapes" do
    let(:banner) { "div[class~='aspect-[4/3]'][class~='sm:aspect-[2/1]']" }
    let(:standard) { "div[class~='aspect-[3/2]']" }

    it "frames the home carousel as a banner and topic cards in the standard shape" do
      sector = create(:sector, :published, name: "Homelessness", story_share_position: 1)
      featured = create(:story, :published, :publicly_visible, title: "Carousel story", story_share_carousel_position: 1)
      topic = create(:story, :published, :publicly_visible, title: "Topic story")
      topic.sectorable_items.create!(sector: sector, is_primary: true)

      get story_shares_path

      page = Capybara.string(response.body)
      expect(page.find(".swiper-slide", text: featured.title)).to have_css(banner)
      expect(page.find("article", text: topic.title)).to have_css(standard)
    end

    it "frames the single-topic lead as a banner and browse cards in the standard shape" do
      sector = create(:sector, :published, name: "Homelessness", story_share_position: 1)
      older = create(:story, :published, :publicly_visible, title: "Older card story", created_at: 2.days.ago)
      lead = create(:story, :published, :publicly_visible, title: "Newer lead story")
      [ older, lead ].each { |s| s.sectorable_items.create!(sector: sector, is_primary: true) }

      get story_shares_path(sector_names_all: "Homelessness")

      page = Capybara.string(response.body)
      expect(page).to have_css(banner, count: 1)
      expect(page.find("article", text: older.title)).to have_css(standard)
    end
  end

  # ==========================================================
  # "What others are reading" — most-read by Ahoy view count
  # ==========================================================
  describe "\"What others are reading\" section" do
    def record_views(story, count)
      count.times { create(:ahoy_event, name: "view.story", properties: { resource_type: "Story", resource_id: story.id }) }
    end

    it "orders stories by tracked Ahoy view count, most-read first" do
      most_read = create(:story, :published, :publicly_visible, title: "The most read story")
      less_read = create(:story, :published, :publicly_visible, title: "The less read story")
      record_views(most_read, 3)
      record_views(less_read, 1)

      get story_shares_path

      section = response.body.split("What others are reading").last
      expect(section.index(most_read.title)).to be < section.index(less_read.title)
    end
  end

  # ==========================================================
  # SHOW edge cases
  # ==========================================================
  describe "GET /show edge cases" do
    it "renders a story with no organization" do
      orgless = create(:story, :published, :publicly_visible, organization: nil)
      get story_share_path(orgless)
      expect(response).to have_http_status(:ok)
    end

    it "redirects to the external website_url when present" do
      external = create(:story, :published, :publicly_visible, website_url: "https://example.com/story")
      get story_share_path(external)
      expect(response).to redirect_to("https://example.com/story")
    end

    it "does not redirect when no_redirect is set" do
      external = create(:story, :published, :publicly_visible, website_url: "https://example.com/story")
      get story_share_path(external, no_redirect: 1)
      expect(response).to have_http_status(:ok)
    end

    it "links every workshop the story came from" do
      first = create(:workshop, :published, :publicly_visible, title: "Mask Making")
      second = create(:workshop, :published, :publicly_visible, title: "Collage Stories")
      story = create(:story, :published, :publicly_visible, workshop: nil)
      story.story_workshops.create!(workshop: first)
      story.story_workshops.create!(workshop: second)

      get story_share_path(story)

      page = Capybara.string(response.body)
      expect(page).to have_text("Workshops:")
      expect(page).to have_link("Mask Making", href: workshop_path(first))
      expect(page).to have_link("Collage Stories", href: workshop_path(second))
    end

    it "shows a workshop the guest can't open as plain text" do
      hidden = create(:workshop, :published, title: "Members Only Workshop")
      story = create(:story, :published, :publicly_visible, workshop: hidden)

      get story_share_path(story)

      page = Capybara.string(response.body)
      expect(page).to have_text("Workshop: Members Only Workshop")
      expect(page).not_to have_link("Members Only Workshop")
    end
  end

  # ==========================================================
  # SHARE (signed-in submission)
  # ==========================================================
  describe "GET /new" do
    it "redirects guests to sign in" do
      get new_story_share_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the submission form for signed-in users" do
      sign_in regular_user
      get new_story_share_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "submitting a story from the portal" do
    let(:submitter)    { create(:user, :with_person) }
    let(:organization) { create(:organization) }

    before do
      sign_in submitter
      create(:affiliation, person: submitter.person, organization: organization)
    end

    it "redirects back to the portal with a thank-you notice" do
      post story_ideas_path, params: {
        return_to: "story_share",
        story_idea: {
          rhino_body: "<p>My workshop story</p>",
          organization_id: organization.id,
          windows_type_id: windows_type.id,
          permission_given: true,
          author_credit_preference: "anonymous"
        }
      }
      expect(response).to redirect_to(story_shares_path)
      follow_redirect!
      expect(response.body).to include("Thank you for sharing your story")
    end
  end
end
