require "rails_helper"

RSpec.describe StaffTaggingsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/staff_taggings").to route_to("staff_taggings#index")
    end

    it "routes to #edit" do
      expect(get: "/staff_taggings/1/edit").to route_to("staff_taggings#edit", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/staff_taggings/1").to route_to("staff_taggings#update", id: "1")
    end

    it "routes to #destroy via DELETE" do
      expect(delete: "/staff_taggings/1").to route_to("staff_taggings#destroy", id: "1")
    end
  end
end
