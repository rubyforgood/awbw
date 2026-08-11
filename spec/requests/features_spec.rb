require "rails_helper"

RSpec.describe "/features", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let!(:user_facing) { create(:feature, name: "Facilitator feature", display_status: "user_facing", published: true) }
  let!(:admin_facing) { create(:feature, name: "Admin-only feature", display_status: "admin_facing", published: true) }
  let!(:draft) { create(:feature, name: "Draft feature", display_status: "user_facing", published: false) }

  describe "GET /features" do
    it "redirects a logged-out visitor to sign in" do
      get features_path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "shows published, non-admin-facing features only" do
        get features_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Facilitator feature")
        expect(response.body).not_to include("Admin-only feature")
        expect(response.body).not_to include("Draft feature")
      end

      it "does not show admin actions" do
        get features_path
        expect(response.body).not_to include("Import from seed")
        expect(response.body).not_to include("New feature")
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "shows every feature and the admin actions" do
        get features_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Facilitator feature")
        expect(response.body).to include("Admin-only feature")
        expect(response.body).to include("Draft feature")
        expect(response.body).to include("Import from seed")
        expect(response.body).to include("New feature")
      end
    end
  end

  describe "GET /features/:id" do
    context "as a regular user" do
      before { sign_in regular_user }

      it "shows a published, non-admin-facing feature" do
        get feature_path(user_facing)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Facilitator feature")
      end

      it "blocks an admin-facing feature" do
        get feature_path(admin_facing)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "shows an admin-facing feature" do
        get feature_path(admin_facing)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Admin-only feature")
      end
    end
  end

  describe "POST /features" do
    let(:valid_attributes) do
      { name: "Brand new", area: "events", display_status: "user_facing",
        summary: "Something useful.", released_on: "2026-08-11" }
    end

    it "lets an admin create a feature" do
      sign_in admin
      expect { post features_path, params: { feature: valid_attributes } }.to change(Feature, :count).by(1)
      expect(response).to redirect_to(Feature.find_by(name: "Brand new"))
    end

    it "blocks a regular user" do
      sign_in regular_user
      expect { post features_path, params: { feature: valid_attributes } }.not_to change(Feature, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /features/import" do
    it "hydrates missing features from the seed for an admin" do
      sign_in admin
      expect { post import_features_path }.to change(Feature, :count)
      expect(response).to redirect_to(features_path)
    end

    it "blocks a regular user" do
      sign_in regular_user
      expect { post import_features_path }.not_to change(Feature, :count)
      expect(response).to redirect_to(root_path)
    end
  end
end
