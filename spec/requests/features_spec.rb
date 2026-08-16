require "rails_helper"

RSpec.describe "/features", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let!(:user_facing) { create(:feature, name: "Facilitator feature", display_status: "user_facing", published: true) }
  let!(:admin_facing) { create(:feature, name: "Admin-only feature", display_status: "admin_facing", published: true) }
  let!(:draft) { create(:feature, name: "Draft feature", display_status: "user_facing", published: false) }

  # The list loads lazily in a Turbo frame; the full page renders the shell + form,
  # and the frame request renders the filtered cards.
  def frame_headers
    { "Turbo-Frame" => "features_results" }
  end

  describe "GET /features (page shell)" do
    it "redirects a logged-out visitor to sign in" do
      get features_path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "renders the page with the search form" do
        get features_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Features &amp; tips")
        expect(response.body).to include('name="query"')
      end

      it "does not show admin actions" do
        get features_path
        expect(response.body).not_to include("Sync latest updates")
        expect(response.body).not_to include("New feature")
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "shows the New feature action (sync lives on the admin home)" do
        get features_path
        expect(response.body).to include("New feature")
        expect(response.body).not_to include("Sync latest updates")
      end
    end
  end

  describe "GET /features (results frame)" do
    context "as a regular user" do
      before { sign_in regular_user }

      it "lists published, non-admin-facing features only" do
        get features_path, headers: frame_headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Facilitator feature")
        expect(response.body).not_to include("Admin-only feature")
        expect(response.body).not_to include("Draft feature")
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "lists every feature" do
        get features_path, headers: frame_headers
        expect(response.body).to include("Facilitator feature")
        expect(response.body).to include("Admin-only feature")
        expect(response.body).to include("Draft feature")
      end

      it "card links break out of the results frame (so Details opens the show page)" do
        get features_path, headers: frame_headers
        expect(response.body).to include('data-turbo-frame="_top"')
      end

      it "filters by a search query across name/summary" do
        get features_path, params: { query: "Admin-only" }, headers: frame_headers
        expect(response.body).to include("Admin-only feature")
        expect(response.body).not_to include("Facilitator feature")
      end

      it "filters by audience" do
        get features_path, params: { display_status: "admin_facing" }, headers: frame_headers
        expect(response.body).to include("Admin-only feature")
        expect(response.body).not_to include("Facilitator feature")
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
