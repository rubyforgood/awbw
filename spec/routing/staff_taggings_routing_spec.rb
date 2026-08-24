require "rails_helper"

RSpec.describe StaffTaggingsController, type: :routing do
  describe "routing" do
    it "routes to #edit" do
      expect(get: "/staff_taggings/1/edit").to route_to("staff_taggings#edit", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/staff_taggings/1").to route_to("staff_taggings#update", id: "1")
    end

    it "does not route to #index" do
      expect(get: "/staff_taggings").not_to be_routable
    end
  end
end
