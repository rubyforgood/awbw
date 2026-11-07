require "rails_helper"

RSpec.describe StorySharesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/story_share").to route_to("story_shares#index")
    end

    it "routes to #show" do
      expect(get: "/story_share/1").to route_to("story_shares#show", id: "1")
    end

    it "routes the hero story picker to the admin controller" do
      expect(patch: "/story_share/admin/hero_story").to route_to("story_share_admin#update_hero_story")
    end
  end
end
