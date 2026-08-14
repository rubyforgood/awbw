require "rails_helper"

RSpec.describe Api::V1::GrantsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/api/v1/grants").to route_to("api/v1/grants#index", format: "json")
    end

    it "routes to #show" do
      expect(get: "/api/v1/grants/1").to route_to("api/v1/grants#show", id: "1", format: "json")
    end

    it "does not route to #create" do
      expect(post: "/api/v1/grants").not_to be_routable
    end
  end
end
