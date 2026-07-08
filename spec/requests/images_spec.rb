require "rails_helper"

RSpec.describe "/images", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:frame_headers) { { "Turbo-Frame" => "images_results" } }

  describe "authorization" do
    it "redirects non-admins away from the index" do
      sign_in create(:user)
      get images_url
      expect(response).to redirect_to(root_path)
    end

    it "redirects anonymous users away from the index" do
      get images_url
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "as an admin" do
    before { sign_in admin }

    describe "GET /index" do
      it "renders a successful response" do
        create(:primary_asset, title: "Hero shot")
        get images_url
        expect(response).to be_successful
      end

      it "lists assets of every type in the frame" do
        primary = create(:primary_asset, title: "Primary label")
        gallery = create(:gallery_asset, title: "Gallery label")
        rich    = create(:rich_text_asset, title: "Rich label")

        get images_url, headers: frame_headers

        expect(response.body).to include("Primary label", "Gallery label", "Rich label")
        expect(response.body).to include("Primary asset", "Gallery asset", "Rich text asset")
        expect(response.body).to include(image_path(primary), image_path(gallery), image_path(rich))
      end

      it "filters by asset type" do
        create(:primary_asset, title: "A primary")
        create(:gallery_asset, title: "A gallery")

        get images_url(type: "PrimaryAsset"), headers: frame_headers
        expect(response.body).to include("A primary")
        expect(response.body).not_to include("A gallery")
      end

      it "filters by the record it's attached to" do
        create(:primary_asset, title: "On workshop", owner: create(:workshop))
        create(:primary_asset, title: "On story", owner: create(:story))

        get images_url(owner_type: "Workshop"), headers: frame_headers
        expect(response.body).to include("On workshop")
        expect(response.body).not_to include("On story")
      end

      it "searches by title and filename" do
        create(:primary_asset, title: "Distinctive title")
        create(:gallery_asset, :with_file, title: "plain")

        get images_url(query: "Distinctive"), headers: frame_headers
        expect(response.body).to include("Distinctive title")
        expect(response.body).not_to include(">plain<")

        get images_url(query: "missing.png"), headers: frame_headers
        expect(response.body).to include("missing.png")
      end
    end

    describe "PATCH /update" do
      it "updates the asset's title (label)" do
        asset = create(:gallery_asset, title: "Old")
        patch image_url(asset), params: { asset: { title: "New label" } }
        expect(response).to be_successful
        expect(asset.reload.title).to eq("New label")
        expect(response.body).to include("New label")
      end
    end
  end

  describe "PATCH /update as a non-admin" do
    it "does not update the title" do
      asset = create(:gallery_asset, title: "Old")
      sign_in create(:user)
      patch image_url(asset), params: { asset: { title: "Hacked" } }
      expect(response).to redirect_to(root_path)
      expect(asset.reload.title).to eq("Old")
    end
  end
end
