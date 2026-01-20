require "rails_helper"

RSpec.describe OrganizationStatusesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/organization_statuses").to route_to("organization_statuses#index")
    end

    it "routes to #new" do
      expect(get: "/organization_statuses/new").to route_to("organization_statuses#new")
    end

    it "routes to #show" do
      expect(get: "/organization_statuses/1").to route_to("organization_statuses#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/organization_statuses/1/edit").to route_to("organization_statuses#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/organization_statuses").to route_to("organization_statuses#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/organization_statuses/1").to route_to("organization_statuses#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/organization_statuses/1").to route_to("organization_statuses#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/organization_statuses/1").to route_to("organization_statuses#destroy", id: "1")
    end
  end
end
