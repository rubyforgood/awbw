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

  it "routes registration show (only the registration lane has show)" do
    expect(get: "/events/1/forms/registration").to route_to(
      "events/public_forms#show", event_id: "1", form_role: "registration"
    )
  end

  it "does not expose show for non-registration lanes" do
    expect(get: "/events/1/forms/scholarship").not_to be_routable
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
