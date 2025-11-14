require "rails_helper"

RSpec.describe CommunityNewsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/community_news").to route_to("community_news#index")
    end

    it "routes to #new" do
      expect(get: "/community_news/new").to route_to("community_news#new")
    end

    it "routes to #show" do
      expect(get: "/community_news/1").to route_to("community_news#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/community_news/1/edit").to route_to("community_news#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/community_news").to route_to("community_news#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/community_news/1").to route_to("community_news#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/community_news/1").to route_to("community_news#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/community_news/1").to route_to("community_news#destroy", id: "1")
    end
  end
end
