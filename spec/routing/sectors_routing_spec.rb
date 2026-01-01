require "rails_helper"

RSpec.describe SectorsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/sectors").to route_to("sectors#index")
    end

    it "routes to #new" do
      expect(get: "/sectors/new").to route_to("sectors#new")
    end

    it "routes to #show" do
      expect(get: "/sectors/1").to route_to("sectors#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/sectors/1/edit").to route_to("sectors#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/sectors").to route_to("sectors#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/sectors/1").to route_to("sectors#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/sectors/1").to route_to("sectors#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/sectors/1").to route_to("sectors#destroy", id: "1")
    end
  end
end
