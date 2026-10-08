require "rails_helper"

RSpec.describe "StoryShareAdmin", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe "GET /story_share/admin" do
    it "renders for admins" do
      sign_in admin
      get story_share_admin_path
      expect(response).to have_http_status(:ok)
    end

    it "lists the fixed top-nav items without controls" do
      sign_in admin
      get story_share_admin_path
      expect(response.body).to include("Home")
      expect(response.body).to include("Facilitator Spotlights")
      expect(response.body).to include("Additional Focus Areas")
      expect(response.body).to include("Always shown")
    end

    it "groups the second nav into age ranges, then story populations" do
      sign_in admin
      age_range = create(:category_type, name: "AgeRange")
      population = create(:category_type, name: "StoryPopulation")
      create(:category, :published, name: "Teens", category_type: age_range, story_share_position: 1)
      create(:category, :published, name: "Elders", category_type: age_range)
      create(:category, :published, name: "Self", category_type: population, story_share_position: 1)
      create(:category, name: "Children_", category_type: population, story_share_position: 2)

      get story_share_admin_path

      page = Capybara.string(response.body)
      expect(response.body.index("Age ranges")).to be < response.body.index("Story populations")
      expect(page).to have_css("li[data-sortable-id]", text: "Teens")
      expect(page).to have_css("select[name='id'] option", text: "Elders")
      expect(page.find("li[data-sortable-id]", text: "Children_")).to have_text("Unpublished — hidden from the nav")
    end

    it "does not render for non-admins" do
      sign_in regular_user
      get story_share_admin_path
      expect(response).not_to have_http_status(:ok)
    end

    it "redirects guests to sign in" do
      get story_share_admin_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST /story_share/admin/add" do
    before { sign_in admin }

    it "sets story_share_position on a sector and redirects" do
      sector = create(:sector, :published, name: "Homelessness")
      post story_share_admin_add_path(type: "sector"), params: { id: sector.id }
      expect(sector.reload.story_share_position).to eq(1)
      expect(response).to redirect_to(story_share_admin_path)
    end

    it "appends after existing featured items" do
      create(:sector, :published, story_share_position: 1)
      later = create(:sector, :published)
      post story_share_admin_add_path(type: "sector"), params: { id: later.id }
      expect(later.reload.story_share_position).to eq(2)
    end

    it "works for categories, numbering within the category's group" do
      age_range = create(:category_type, name: "AgeRange")
      population = create(:category_type, name: "StoryPopulation")
      create(:category, :published, category_type: population, story_share_position: 1)
      create(:category, :published, category_type: population, story_share_position: 2)
      category = create(:category, :published, category_type: age_range)
      post story_share_admin_add_path(type: "category"), params: { id: category.id }
      expect(category.reload.story_share_position).to eq(1)
    end

    it "refuses a category that is neither an age range nor a story population" do
      category = create(:category, :published)
      post story_share_admin_add_path(type: "category"), params: { id: category.id }
      expect(category.reload.story_share_position).to be_nil
      expect(flash[:alert]).to include("Only age ranges and story populations")
    end

    it "redirects back without error when nothing is selected" do
      expect {
        post story_share_admin_add_path(type: "sector"), params: { id: "" }
      }.not_to raise_error
      expect(response).to redirect_to(story_share_admin_path)
    end

    it "does not track an event when nothing is selected" do
      expect(Analytics::AhoyTracker).not_to receive(:track_event)
      post story_share_admin_add_path(type: "sector"), params: { id: "" }
    end
  end

  describe "reorder URL template" do
    # sortable_controller.js does urlValue.replace(":id", id), so the rendered
    # template must carry a literal ":id". A query-string id encodes the colon to
    # %3Aid, the replace misses, and every reorder hits id=:id (not_found) — so
    # keep :id in the path segment.
    it "keeps :id as a literal placeholder the sortable JS can substitute" do
      url = story_share_admin_reorder_path(type: "sector", id: ":id")
      expect(url).to include(":id")
      expect(url).not_to include("%3A")
    end
  end

  describe "PUT /story_share/admin/reorder" do
    before { sign_in admin }

    it "renumbers story_share_position to place the moved item at the new position" do
      a = create(:sector, :published, story_share_position: 1)
      b = create(:sector, :published, story_share_position: 2)
      c = create(:sector, :published, story_share_position: 3)

      put story_share_admin_reorder_path(type: "sector", id: c.id), params: { position: 1 }

      expect(c.reload.story_share_position).to eq(1)
      expect(a.reload.story_share_position).to eq(2)
      expect(b.reload.story_share_position).to eq(3)
    end

    it "reorders a category within its own group, leaving the other group alone" do
      age_range = create(:category_type, name: "AgeRange")
      population = create(:category_type, name: "StoryPopulation")
      children = create(:category, :published, category_type: age_range, story_share_position: 1)
      teens = create(:category, :published, category_type: age_range, story_share_position: 2)
      self_category = create(:category, :published, category_type: population, story_share_position: 1)

      put story_share_admin_reorder_path(type: "category", id: teens.id), params: { position: 1 }

      expect(teens.reload.story_share_position).to eq(1)
      expect(children.reload.story_share_position).to eq(2)
      expect(self_category.reload.story_share_position).to eq(1)
    end
  end

  describe "DELETE /story_share/admin/remove" do
    before { sign_in admin }

    it "clears story_share_position and renumbers the rest" do
      a = create(:sector, :published, story_share_position: 1)
      b = create(:sector, :published, story_share_position: 2)

      delete story_share_admin_remove_path(type: "sector", id: a.id)

      expect(a.reload.story_share_position).to be_nil
      expect(b.reload.story_share_position).to eq(1)
    end

    it "renumbers only the removed category's group" do
      age_range = create(:category_type, name: "AgeRange")
      population = create(:category_type, name: "StoryPopulation")
      children = create(:category, :published, category_type: age_range, story_share_position: 1)
      teens = create(:category, :published, category_type: age_range, story_share_position: 2)
      community = create(:category, :published, category_type: population, story_share_position: 2)

      delete story_share_admin_remove_path(type: "category", id: children.id)

      expect(teens.reload.story_share_position).to eq(1)
      expect(community.reload.story_share_position).to eq(2)
    end
  end

  describe "PUT /story_share/admin/toggle_home_section" do
    before { sign_in admin }

    it "turns a category's home section off, then back on" do
      category = create(:category, :published, story_share_position: 1)
      expect(category.story_share_home_section).to be(true)

      put story_share_admin_toggle_home_section_path(type: "category", id: category.id)
      expect(category.reload.story_share_home_section).to be(false)
      expect(response).to redirect_to(story_share_admin_path)

      put story_share_admin_toggle_home_section_path(type: "category", id: category.id)
      expect(category.reload.story_share_home_section).to be(true)
    end

    it "toggles a sector's home section" do
      sector = create(:sector, :published, story_share_position: 1)
      put story_share_admin_toggle_home_section_path(type: "sector", id: sector.id)
      expect(sector.reload.story_share_home_section).to be(false)
    end

    it "sets an explicit value from the dropdown idempotently" do
      category = create(:category, :published, story_share_position: 1)
      put story_share_admin_toggle_home_section_path(type: "category", id: category.id), params: { on_home: false }
      expect(category.reload.story_share_home_section).to be(false)
      put story_share_admin_toggle_home_section_path(type: "category", id: category.id), params: { on_home: false }
      expect(category.reload.story_share_home_section).to be(false)
      put story_share_admin_toggle_home_section_path(type: "category", id: category.id), params: { on_home: true }
      expect(category.reload.story_share_home_section).to be(true)
    end

    it "records an Ahoy event for the toggle" do
      category = create(:category, :published, story_share_position: 1)
      expect(Analytics::AhoyTracker).to receive(:track_event)
        .with(anything, "update.story_share_home_section",
              hash_including(resource_type: "Category", resource_id: category.id,
                             changes: { story_share_home_section: false }))
      put story_share_admin_toggle_home_section_path(type: "category", id: category.id)
    end

    it "forbids non-admins" do
      sign_out admin
      sign_in regular_user
      category = create(:category, :published, story_share_position: 1)
      put story_share_admin_toggle_home_section_path(type: "category", id: category.id)
      expect(category.reload.story_share_home_section).to be(true)
    end
  end

  describe "Ahoy tracking" do
    before { sign_in admin }

    it "records an event when a sector is added to the menu" do
      sector = create(:sector, :published, name: "Homelessness")
      expect(Analytics::AhoyTracker).to receive(:track_event)
        .with(anything, "create.story_share_menu",
              hash_including(resource_type: "Sector", resource_id: sector.id, resource_title: "Homelessness"))
      post story_share_admin_add_path(type: "sector"), params: { id: sector.id }
    end

    it "records an event when a category is added to the menu" do
      category = create(:category, :published, category_type: create(:category_type, name: "AgeRange"))
      expect(Analytics::AhoyTracker).to receive(:track_event)
        .with(anything, "create.story_share_menu", hash_including(resource_type: "Category", resource_id: category.id))
      post story_share_admin_add_path(type: "category"), params: { id: category.id }
    end

    it "records a before/after position change when a menu item is reordered" do
      a = create(:sector, :published, story_share_position: 1)
      b = create(:sector, :published, story_share_position: 2)
      expect(Analytics::AhoyTracker).to receive(:track_event)
        .with(anything, "update.story_share_menu",
              hash_including(resource_type: "Sector", resource_id: b.id,
                             changes: { position: { before: 2, after: 1 } }))
      put story_share_admin_reorder_path(type: "sector", id: b.id), params: { position: 1 }
    end

    it "does not record an event when the position is unchanged" do
      a = create(:sector, :published, story_share_position: 1)
      create(:sector, :published, story_share_position: 2)
      expect(Analytics::AhoyTracker).not_to receive(:track_event)
      put story_share_admin_reorder_path(type: "sector", id: a.id), params: { position: 1 }
    end

    it "records an event when a menu item is removed" do
      sector = create(:sector, :published, story_share_position: 1)
      expect(Analytics::AhoyTracker).to receive(:track_event)
        .with(anything, "destroy.story_share_menu",
              hash_including(resource_type: "Sector", resource_id: sector.id))
      delete story_share_admin_remove_path(type: "sector", id: sector.id)
    end
  end

  describe "GET /search/:model for the pickers" do
    it "returns sectors for an admin" do
      sign_in admin
      create(:sector, :published, name: "Homelessness")
      get "/search/sector", params: { q: "Home" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |r| r["label"] }).to include("Homelessness")
    end

    it "forbids non-admins from searching sectors" do
      sign_in regular_user
      create(:sector, :published, name: "Homelessness")
      get "/search/sector", params: { q: "Home" }
      expect(response).not_to have_http_status(:ok)
    end
  end
end
