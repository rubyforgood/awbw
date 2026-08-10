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
      workshop_id: workshop.id,
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
    end

    describe "GET /show" do
      it "can view any story" do
        get story_share_path(private_story)
        expect(response).to have_http_status(:ok)
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
  end

  # ==========================================================
  # BROWSING / FILTERING (public)
  # ==========================================================
  describe "browsing filtered results" do
    def tag_sector(story, name)
      sector = Sector.find_by(name: name) || create(:sector, :published, name: name)
      story.sectorable_items.create!(sector: sector)
      sector
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
      teen_story.categorizable_items.create!(category: teens)

      get story_shares_path(category_names_all: "Teens")
      expect(response.body).to include("A teen art story")
      expect(response.body).not_to include("An unrelated story")
    end

    it "filters by facilitator spotlights" do
      spotlight = create(:story, :published, :publicly_visible, title: "A spotlighted facilitator", spotlighted_facilitator: create(:person))
      get story_shares_path(facilitator_spotlights: true)
      expect(response.body).to include("A spotlighted facilitator")
      expect(response.body).not_to include("An unrelated story")
    end

    it "does not leak non-public stories to guests when browsing" do
      create(:story, :published, title: "A published-only secret", publicly_visible: false).tap { |s| tag_sector(s, "Domestic Violence") }
      get story_shares_path(sector_names_all: "Domestic Violence")
      expect(response.body).not_to include("A published-only secret")
    end

    it "aggregates non-featured sectors on the additional focus areas page" do
      featured = create(:sector, :published, name: "Featured Sector", story_share_position: 1)
      extra = create(:sector, :published, name: "Homelessness")
      create(:story, :published, :publicly_visible, title: "A featured-only story").tap { |s| s.sectorable_items.create!(sector: featured) }
      create(:story, :published, :publicly_visible, title: "An additional-area story").tap { |s| s.sectorable_items.create!(sector: extra) }

      get story_shares_path(additional_focus_areas: true)
      expect(response.body).to include("An additional-area story")
      expect(response.body).not_to include("A featured-only story")
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
  end

  # ==========================================================
  # SHARE (signed-in submission)
  # ==========================================================
  describe "GET /share" do
    it "redirects guests to sign in" do
      get share_story_shares_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the submission form for signed-in users" do
      sign_in regular_user
      get share_story_shares_path
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
