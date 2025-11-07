require "rails_helper"

RSpec.describe BannersController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/banners").to route_to("banners#index")
    end

    it "routes to #new" do
      expect(get: "/banners/new").to route_to("banners#new")
    end

    it "routes to #show" do
      expect(get: "/banners/1").to route_to("banners#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/banners/1/edit").to route_to("banners#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/banners").to route_to("banners#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/banners/1").to route_to("banners#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/banners/1").to route_to("banners#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/banners/1").to route_to("banners#destroy", id: "1")
    end
  end
end
