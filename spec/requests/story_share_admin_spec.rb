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

    it "works for categories" do
      category = create(:category, :published)
      post story_share_admin_add_path(type: "category"), params: { id: category.id }
      expect(category.reload.story_share_position).to eq(1)
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
      category = create(:category, :published)
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
