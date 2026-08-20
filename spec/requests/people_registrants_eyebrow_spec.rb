require "rails_helper"

RSpec.describe "Person profile back-to-registrants eyebrow", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }
  let(:person) { create(:person) }

  before { sign_in admin }

  it "shows a Back to registrants link when arriving from the event registrants page" do
    get person_path(person, return_to: "registrants", event_id: event.id)

    expect(response.body).to include("Back to registrants")
    expect(response.body).to include(registrants_event_path(event))
  end

  it "omits the link without the registrants return context" do
    get person_path(person)

    expect(response.body).not_to include("Back to registrants")
  end
end
