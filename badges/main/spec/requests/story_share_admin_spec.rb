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
