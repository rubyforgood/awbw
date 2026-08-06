require "rails_helper"

RSpec.describe EventsController, type: :routing do
  describe "routing" do
    it "routes to #dashboard" do
      expect(get: "/events/1/dashboard").to route_to("events#dashboard", id: "1")
    end

    it "routes to #scholarships" do
      expect(get: "/events/scholarships").to route_to("events#scholarships")
    end
  end
end
