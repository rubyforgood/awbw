require "rails_helper"

RSpec.describe "/gallery_assets", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:story)        { create(:story) }

  describe "DELETE /gallery_assets/:id" do
    let!(:gallery_asset) { create(:gallery_asset, :with_file, owner: story) }

    context "as admin" do
      before { sign_in admin }

      it "removes the gallery image" do
        expect {
          delete gallery_asset_url(gallery_asset)
        }.to change(Asset, :count).by(-1)

        expect(response).to redirect_to(story_url(story))
        expect(Asset.exists?(gallery_asset.id)).to be(false)
      end
    end

    context "as a non-admin user" do
      before { sign_in regular_user }

      it "does not remove the image" do
        expect {
          delete gallery_asset_url(gallery_asset)
        }.not_to change(Asset, :count)
      end
    end

    context "when signed out" do
      it "does not remove the image" do
        expect {
          delete gallery_asset_url(gallery_asset)
        }.not_to change(Asset, :count)
      end
    end
  end

  describe "POST /gallery_assets/:id/make_primary" do
    let!(:gallery_asset) { create(:gallery_asset, :with_file, owner: story) }

    context "as admin" do
      before { sign_in admin }

      it "promotes the gallery image to the featured image" do
        post make_primary_gallery_asset_url(gallery_asset)

        expect(response).to redirect_to(story_url(story))
        expect(Asset.find(gallery_asset.id).type).to eq("PrimaryAsset")
      end

      it "demotes the existing featured image to the gallery" do
        existing_primary = create(:primary_asset, :with_file, owner: story)

        post make_primary_gallery_asset_url(gallery_asset)

        expect(Asset.find(existing_primary.id).type).to eq("GalleryAsset")
        expect(Asset.find(gallery_asset.id).type).to eq("PrimaryAsset")
        expect(story.assets.where(type: "PrimaryAsset").count).to eq(1)
      end
    end

    context "as a non-admin user" do
      before { sign_in regular_user }

      it "does not change the asset type" do
        post make_primary_gallery_asset_url(gallery_asset)

        expect(Asset.find(gallery_asset.id).type).to eq("GalleryAsset")
      end
    end
  end
end
