require "rails_helper"

RSpec.describe FaqsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/faqs").to route_to("faqs#index")
    end

    it "routes to #new" do
      expect(get: "/faqs/new").to route_to("faqs#new")
    end

    it "routes to #show" do
      expect(get: "/faqs/1").to route_to("faqs#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/faqs/1/edit").to route_to("faqs#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/faqs").to route_to("faqs#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/faqs/1").to route_to("faqs#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/faqs/1").to route_to("faqs#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/faqs/1").to route_to("faqs#destroy", id: "1")
    end
  end
end
