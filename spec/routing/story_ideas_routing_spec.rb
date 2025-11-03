require "rails_helper"

RSpec.describe StoryIdeasController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/story_ideas").to route_to("story_ideas#index")
    end

    it "routes to #new" do
      expect(get: "/story_ideas/new").to route_to("story_ideas#new")
    end

    it "routes to #show" do
      expect(get: "/story_ideas/1").to route_to("story_ideas#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/story_ideas/1/edit").to route_to("story_ideas#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/story_ideas").to route_to("story_ideas#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/story_ideas/1").to route_to("story_ideas#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/story_ideas/1").to route_to("story_ideas#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/story_ideas/1").to route_to("story_ideas#destroy", id: "1")
    end
  end
end
