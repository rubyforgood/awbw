require "rails_helper"

RSpec.describe Api::V1::StoriesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/api/v1/stories").to route_to("api/v1/stories#index", format: "json")
    end

    it "routes to #show" do
      expect(get: "/api/v1/stories/1").to route_to("api/v1/stories#show", id: "1", format: "json")
    end

    it "does not route to #create" do
      expect(post: "/api/v1/stories").not_to be_routable
    end
  end
end
