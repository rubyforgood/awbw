require "rails_helper"

RSpec.describe GrantsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/grants").to route_to("grants#index")
    end

    it "routes to #new" do
      expect(get: "/grants/new").to route_to("grants#new")
    end

    it "routes to #show" do
      expect(get: "/grants/1").to route_to("grants#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/grants/1/edit").to route_to("grants#edit", id: "1")
    end

    it "routes to #create" do
      expect(post: "/grants").to route_to("grants#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/grants/1").to route_to("grants#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/grants/1").to route_to("grants#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/grants/1").to route_to("grants#destroy", id: "1")
    end
  end
end
