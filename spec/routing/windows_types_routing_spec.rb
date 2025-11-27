require "rails_helper"

RSpec.describe WindowsTypesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/windows_types").to route_to("windows_types#index")
    end

    it "routes to #new" do
      expect(get: "/windows_types/new").to route_to("windows_types#new")
    end

    it "routes to #show" do
      expect(get: "/windows_types/1").to route_to("windows_types#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/windows_types/1/edit").to route_to("windows_types#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/windows_types").to route_to("windows_types#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/windows_types/1").to route_to("windows_types#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/windows_types/1").to route_to("windows_types#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/windows_types/1").to route_to("windows_types#destroy", id: "1")
    end
  end
end
