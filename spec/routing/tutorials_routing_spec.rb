require "rails_helper"

RSpec.describe TutorialsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/tutorials").to route_to("tutorials#index")
    end

    it "routes to #new" do
      expect(get: "/tutorials/new").to route_to("tutorials#new")
    end

    it "routes to #show" do
      expect(get: "/tutorials/1").to route_to("tutorials#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/tutorials/1/edit").to route_to("tutorials#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/tutorials").to route_to("tutorials#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/tutorials/1").to route_to("tutorials#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/tutorials/1").to route_to("tutorials#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/tutorials/1").to route_to("tutorials#destroy", id: "1")
    end
  end
end
