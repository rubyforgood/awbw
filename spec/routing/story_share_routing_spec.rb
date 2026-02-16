require "rails_helper"

RSpec.describe StorySharesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/story_shares").to route_to("story_shares#index")
    end

    it "routes to #show" do
      expect(get: "/story_shares/1").to route_to("story_shares#show", id: "1")
    end
  end
end
