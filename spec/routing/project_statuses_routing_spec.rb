require "rails_helper"

RSpec.describe ProjectStatusesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/project_statuses").to route_to("project_statuses#index")
    end

    it "routes to #new" do
      expect(get: "/project_statuses/new").to route_to("project_statuses#new")
    end

    it "routes to #show" do
      expect(get: "/project_statuses/1").to route_to("project_statuses#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/project_statuses/1/edit").to route_to("project_statuses#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/project_statuses").to route_to("project_statuses#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/project_statuses/1").to route_to("project_statuses#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/project_statuses/1").to route_to("project_statuses#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/project_statuses/1").to route_to("project_statuses#destroy", id: "1")
    end
  end
end
