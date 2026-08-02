require "rails_helper"

RSpec.describe EventsController, type: :routing do
  describe "routing" do
    it "routes to #dashboard" do
      expect(get: "/events/1/dashboard").to route_to("events#dashboard", id: "1")
    end

    it "routes to #facilitator_training_report" do
      expect(get: "/events/facilitator_training_report").to route_to("events#facilitator_training_report")
    end
  end
end
