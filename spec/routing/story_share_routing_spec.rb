require "rails_helper"

RSpec.describe StoryShareController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/stories/share").to route_to("story_share#index")
    end

    it "routes to #show" do
      expect(get: "/stories/share/1").to route_to("story_share#show", id: "1")
    end
  end
end
