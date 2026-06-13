require "rails_helper"

RSpec.describe Events::PublicFormsController, type: :routing do
  %w[registration scholarship scholarship_questions ce_questions general].each do |lane|
    describe "#{lane} lane" do
      it "routes new" do
        expect(get: "/events/1/forms/#{lane}/new").to route_to(
          "events/public_forms#new", event_id: "1", form_role: lane
        )
      end

      it "routes create" do
        expect(post: "/events/1/forms/#{lane}").to route_to(
          "events/public_forms#create", event_id: "1", form_role: lane
        )
      end
    end
  end

  it "routes the slug-based submission view at the top level (not under events)" do
    expect(get: "/submission/abc123").to route_to(
      "events/public_forms#show", slug: "abc123"
    )
  end

  it "no longer exposes the submission view through events routes" do
    expect(get: "/events/1/forms/registration").not_to be_routable
  end

  it "routes bulk_payment under the uniform forms/ path to its own controller" do
    expect(get: "/events/1/forms/bulk_payment/new").to route_to(
      "events/bulk_payments#new", event_id: "1"
    )
  end

  it "does not collide with the registrant registrations route" do
    expect(post: "/events/1/registrations").to route_to(
      "events/registrations#create", event_id: "1"
    )
  end
end
