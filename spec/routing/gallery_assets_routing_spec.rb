require "rails_helper"

RSpec.describe GalleryAssetsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/gallery_assets").to route_to("gallery_assets#index")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/gallery_assets/1").to route_to("gallery_assets#update", id: "1")
    end

    it "does not route to #show" do
      expect(get: "/gallery_assets/1").not_to be_routable
    end
  end
end
