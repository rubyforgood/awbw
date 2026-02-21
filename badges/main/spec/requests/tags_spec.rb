require "rails_helper"

RSpec.describe "Tags index", type: :request do
  let!(:sector) { create(:sector, :published, name: "Youth") }
  let!(:category_type) { create(:category_type, name: "Theme") }
  let!(:category) { create(:category, :published, name: "Healing", category_type: category_type) }
  let!(:workshop) { create(:workshop) }

  before do
    create(:sectorable_item, sector: sector, sectorable: workshop)
    create(:categorizable_item, category: category, categorizable: workshop)
  end

  describe "as a regular user" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "checks authorization via TagPolicy" do
      expect_any_instance_of(TagPolicy)
        .to receive(:index?).and_return(true)

      get tags_path
    end

    it "renders Sectors and Categories skeleton" do
      get tags_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sectors")
      expect(response.body).to include("Categories")
    end

    it "renders sectors frame" do
      get tags_sectors_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Youth")
    end

    it "renders categories frame" do
      get tags_categories_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Healing")
    end

    it "only shows sectors that have at least one sectorable_item" do
      unlinked_sector = create(:sector, :published, name: "Unlinked Sector")
      get tags_sectors_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Youth")
      expect(response.body).not_to include("Unlinked Sector")
    end

    it "only shows categories that have at least one categorizable_item" do
      unlinked_category = create(:category, :published, name: "Unlinked Category", category_type: category_type)
      get tags_categories_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Healing")
      expect(response.body).not_to include("Unlinked Category")
    end

    it "does NOT show admin-only controls" do
      get tags_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Manage sectors")
      expect(response.body).not_to include("Manage categories")
    end
  end

  describe "as an admin" do
    let(:admin) { create(:user, :admin) }

    before { sign_in admin }

    it "renders sectors frame with admin controls" do
      get tags_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Manage sectors")
    end

    it "renders categories frame with admin controls" do
      get tags_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Manage categories")
    end
  end

  describe "as a guest" do
    it "checks authorization via TagPolicy" do
      expect_any_instance_of(TagPolicy)
        .to receive(:index?).and_return(true)
      get tags_path
    end

    it "renders Sectors and Categories skeleton" do
      get tags_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sectors")
      expect(response.body).to include("Categories")
    end

    it "renders sectors frame" do
      get tags_sectors_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Youth")
    end

    it "renders categories frame" do
      get tags_categories_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Healing")
    end

    it "does NOT show admin-only controls" do
      get tags_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Manage sectors")
      expect(response.body).not_to include("Manage categories")
    end
  end
end
