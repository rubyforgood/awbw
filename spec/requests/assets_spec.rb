require "rails_helper"

RSpec.describe "/asset_library", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:frame_headers) { { "Turbo-Frame" => "assets_results" } }

  describe "authorization" do
    it "redirects non-admins away from the index" do
      sign_in create(:user)
      get asset_library_url
      expect(response).to redirect_to(root_path)
    end

    it "redirects anonymous users away from the index" do
      get asset_library_url
      expect(response).to redirect_to(new_user_session_path)
    end

    it "does not let a non-admin create an asset" do
      sign_in create(:user)
      expect {
        post asset_library_url, params: { asset: { type: "PrimaryAsset", title: "Nope" } }
      }.not_to change(Asset, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  context "as an admin" do
    before { sign_in admin }

    describe "GET /index" do
      it "renders a successful response" do
        create(:primary_asset, title: "Hero shot")
        get asset_library_url
        expect(response).to be_successful
      end

      it "lists assets of every type in the frame" do
        primary = create(:primary_asset, title: "Primary label")
        gallery = create(:gallery_asset, title: "Gallery label")
        rich    = create(:rich_text_asset, title: "Rich label")

        get asset_library_url, headers: frame_headers

        expect(response.body).to include("Primary label", "Gallery label", "Rich label")
        expect(response.body).to include("Primary asset", "Gallery asset", "Rich text asset")
        expect(response.body).to include(
          asset_library_asset_path(primary),
          asset_library_asset_path(gallery),
          asset_library_asset_path(rich)
        )
      end

      it "renders a PDF asset without error" do
        create(:gallery_asset, :with_pdf, title: "A PDF handout")
        get asset_library_url, headers: frame_headers
        expect(response).to be_successful
        expect(response.body).to include("A PDF handout", "sample.pdf")
      end

      it "filters by asset type" do
        create(:primary_asset, title: "A primary")
        create(:gallery_asset, title: "A gallery")

        get asset_library_url(type: "PrimaryAsset"), headers: frame_headers
        expect(response.body).to include("A primary")
        expect(response.body).not_to include("A gallery")
      end

      it "filters by the record it's attached to" do
        create(:primary_asset, title: "On workshop", owner: create(:workshop))
        create(:primary_asset, title: "On story", owner: create(:story))

        get asset_library_url(owner_type: "Workshop"), headers: frame_headers
        expect(response.body).to include("On workshop")
        expect(response.body).not_to include("On story")
      end

      it "filters by attached file type" do
        create(:primary_asset, :with_file, title: "A png")
        create(:gallery_asset, :with_pdf, title: "A pdf")

        get asset_library_url(content_type: "application/pdf"), headers: frame_headers
        expect(response.body).to include("A pdf")
        expect(response.body).not_to include("A png")
      end

      it "filters by search visibility" do
        create(:primary_asset, title: "Visible asset", hidden_from_search: false)
        create(:primary_asset, title: "Concealed asset", hidden_from_search: true)

        get asset_library_url(visibility: "hidden"), headers: frame_headers
        expect(response.body).to include("Concealed asset")
        expect(response.body).not_to include("Visible asset")

        get asset_library_url(visibility: "searchable"), headers: frame_headers
        expect(response.body).to include("Visible asset")
        expect(response.body).not_to include("Concealed asset")
      end

      it "searches by caption and filename" do
        create(:primary_asset, title: "Distinctive title")
        create(:gallery_asset, :with_file, title: "plain")

        get asset_library_url(query: "Distinctive"), headers: frame_headers
        expect(response.body).to include("Distinctive title")
        expect(response.body).not_to include(">plain<")

        get asset_library_url(query: "missing.png"), headers: frame_headers
        expect(response.body).to include("missing.png")
      end
    end

    describe "GET /new" do
      it "renders the new-asset form with hidden-from-search pre-checked" do
        get new_asset_library_url
        expect(response).to be_successful
        expect(response.body).to include("checked")
      end
    end

    describe "POST /create" do
      let(:file) { fixture_file_upload("sample.png", "image/png") }

      it "creates an asset, hidden from search by default" do
        expect {
          post asset_library_url, params: {
            asset: { type: "PrimaryAsset", title: "Fresh upload", hidden_from_search: "1", file: file }
          }
        }.to change(Asset, :count).by(1)

        asset = Asset.last
        expect(asset).to be_a(PrimaryAsset)
        expect(asset.title).to eq("Fresh upload")
        expect(asset.hidden_from_search).to be(true)
        expect(asset.file).to be_attached
        expect(response).to redirect_to(asset_library_path)
      end
    end

    describe "PATCH /update" do
      it "updates the asset's caption (title)" do
        asset = create(:gallery_asset, title: "Old")
        patch asset_library_asset_url(asset), params: { asset: { title: "New caption" } }
        expect(response).to be_successful
        expect(asset.reload.title).to eq("New caption")
        expect(response.body).to include("New caption")
      end

      it "renames the download filename" do
        asset = create(:gallery_asset, :with_file)
        patch asset_library_asset_url(asset), params: { asset: { filename: "renamed.png" } }
        expect(response).to be_successful
        expect(asset.reload.file.filename.to_s).to eq("renamed.png")
        expect(response.body).to include("renamed.png")
      end

      it "leaves the caption untouched when only the filename changes" do
        asset = create(:gallery_asset, :with_file, title: "Keep me")
        patch asset_library_asset_url(asset), params: { asset: { filename: "renamed.png" } }
        expect(asset.reload.title).to eq("Keep me")
      end
    end
  end

  describe "PATCH /update as a non-admin" do
    it "does not update the asset" do
      asset = create(:gallery_asset, title: "Old")
      sign_in create(:user)
      patch asset_library_asset_url(asset), params: { asset: { title: "Hacked" } }
      expect(response).to redirect_to(root_path)
      expect(asset.reload.title).to eq("Old")
    end
  end
end
