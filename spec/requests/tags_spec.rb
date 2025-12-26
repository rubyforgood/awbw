require "rails_helper"

RSpec.describe "Tags index", type: :request do
  let!(:sector) { create(:sector, :published, name: "Youth") }
  let!(:category_type) { create(:category_type, name: "Theme") }
  let!(:category) { create(:category, :published, name: "Healing", category_type: category_type) }

  describe "as a regular user" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "renders Service Populations and Categories skeleton" do
      get tags_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Service Populations")
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

  describe "as a super user (admin)" do
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

  describe "when not signed in" do
    it "redirects to sign-in" do
      get tags_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
