require "rails_helper"

RSpec.describe WorkshopIdeasController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/workshop_ideas").to route_to("workshop_ideas#index")
    end

    it "routes to #new" do
      expect(get: "/workshop_ideas/new").to route_to("workshop_ideas#new")
    end

    it "routes to #show" do
      expect(get: "/workshop_ideas/1").to route_to("workshop_ideas#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/workshop_ideas/1/edit").to route_to("workshop_ideas#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/workshop_ideas").to route_to("workshop_ideas#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/workshop_ideas/1").to route_to("workshop_ideas#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/workshop_ideas/1").to route_to("workshop_ideas#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/workshop_ideas/1").to route_to("workshop_ideas#destroy", id: "1")
    end
  end
end
