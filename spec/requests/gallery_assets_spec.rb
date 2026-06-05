require "rails_helper"

RSpec.describe "/gallery_assets", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let!(:gallery_asset) { create(:gallery_asset, :with_file, title: "Sunrise Workshop") }

  describe "GET /gallery_assets" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the gallery" do
        get gallery_assets_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Image gallery")
      end

      it "filters by the search query in a turbo frame request" do
        create(:gallery_asset, :with_file, title: "Evening Class")

        get gallery_assets_path, params: { query: "sunrise" },
            headers: { "Turbo-Frame" => "gallery_results" }

        expect(response.body).to include("Sunrise Workshop")
        expect(response.body).not_to include("Evening Class")
      end
    end

    context "as a non-admin" do
      before { sign_in regular_user }

      it "is not authorized and redirects" do
        get gallery_assets_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed out" do
      it "redirects to sign in" do
        get gallery_assets_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /gallery_assets/:id" do
    context "as an admin" do
      before { sign_in admin }

      it "updates the editable title" do
        patch gallery_asset_path(gallery_asset), params: { gallery_asset: { title: "Tagged: Org A" } }

        expect(response).to have_http_status(:ok)
        expect(gallery_asset.reload.title).to eq("Tagged: Org A")
      end
    end

    context "as a non-admin" do
      before { sign_in regular_user }

      it "is not authorized and does not change the title" do
        patch gallery_asset_path(gallery_asset), params: { gallery_asset: { title: "Hacked" } }

        expect(response).to redirect_to(root_path)
        expect(gallery_asset.reload.title).to eq("Sunrise Workshop")
      end
    end
  end
end
