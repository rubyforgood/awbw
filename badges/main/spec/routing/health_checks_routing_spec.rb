require "rails_helper"

RSpec.describe HealthChecksController, type: :routing do
  it "routes /up/jobs to #jobs" do
    expect(get: "/up/jobs").to route_to("health_checks#jobs")
  end
end
