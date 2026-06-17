# spec/requests/taggings_index_spec.rb
require "rails_helper"

RSpec.describe "Taggings index", type: :request do
  let!(:user) { create(:user) }

  let!(:sector_1) { create(:sector, :published, name: "Substance Abuse") }
  let!(:sector_2) { create(:sector, :published, name: "Youth") }
  let!(:category_type) { create(:category_type, name: "Theme") }
  let!(:category) do
    create(:category, :published, name: "Healing", category_type: category_type)
  end

  let!(:workshop) { create(:workshop, :published, title: "Art for Healing") }

  before do
    # Make the sectors + category actually appear via joins
    create(:sectorable_item, sector: sector_1, sectorable: workshop)
    create(:sectorable_item, sector: sector_2, sectorable: workshop)
    create(:categorizable_item, category: category, categorizable: workshop)

    sign_in user
  end

  describe "GET /taggings" do
    it "renders successfully" do
      get taggings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Select a sector or explore tags")
    end

    it "shows sectors as buttons" do
      get taggings_path
      expect(response.body).to include(sector_1.name)
      expect(response.body).to include(sector_2.name)
    end

    it "shows categories grouped by type" do
      get taggings_path(category_names_all: "Healing")
      expect(response.body).to include("Theme")
      expect(response.body).to include("Healing")
    end
  end

  describe "filtering by sector_names_all" do
    it "filters content by sector" do
      get taggings_path(sector_names_all: "Youth")

      expect(response.body).to include("Youth")
      expect(response.body).to include("Art for Healing")
    end
  end

  describe "filtering by category_names_all" do
    it "filters content by category" do
      get taggings_path(category_names_all: "Healing")
      expect(response.body).to include("Theme: Healing")
      expect(response.body).to include("Art for Healing")
    end
  end

  describe "admin edit buttons" do
    let!(:admin) { create(:user, :admin) }

    before { sign_in admin }

    it "shows a single Edit sector button when filtering by one sector" do
      get taggings_path(sector_names_all: sector_2.name)
      expect(response.body).to include(edit_sector_path(sector_2))
      expect(response.body).to include("Edit sector")
      expect(response.body).not_to include("Edit sector (")
    end

    it "names each sector when filtering by more than one" do
      get taggings_path(sector_names_all: "#{sector_1.name}--#{sector_2.name}")
      expect(response.body).to include("Edit sector (#{sector_1.name})")
      expect(response.body).to include("Edit sector (#{sector_2.name})")
    end

    it "shows an Edit category button when filtering by a category" do
      get taggings_path(category_names_all: category.name)
      expect(response.body).to include(edit_category_path(category))
      expect(response.body).to include("Edit category")
    end
  end

  describe "edit buttons for non-admins" do
    it "does not show edit buttons to a regular signed-in user" do
      get taggings_path(sector_names_all: sector_2.name)
      expect(response.body).not_to include("Edit sector")
    end
  end

  describe "when no matching tags exist" do
    it "does not blow up and renders empty sections" do
      get taggings_path(sector_names_all: "Nonexistent")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Explore all tags")
      expect(response.body).to include("No items have this tag combination")
    end
  end

  describe "as a guest (unauthenticated)" do
    it "renders the index page" do
      get taggings_path
      expect(response).to have_http_status(:ok)
    end

    it "shows published tagged items when filtering by sector" do
      get taggings_path(sector_names_all: sector_1.name)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Art for Healing")
    end
  end
end
