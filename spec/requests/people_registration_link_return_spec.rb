require "rails_helper"

RSpec.describe "Person edit return to registration org-linking", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }
  let(:person) { create(:person) }
  let(:event_registration) { create(:event_registration, event: event, registrant: person) }

  before { sign_in admin }

  it "shows an Organization linking eyebrow when arriving from the linking page" do
    get edit_person_path(person, return_to: "registration_link", event_registration_id: event_registration.id)

    expect(response.body).to include("Organization linking")
    expect(response.body).to include(link_organization_event_registration_path(event_registration))
  end

  it "returns to the linking page after a successful update" do
    patch person_path(person), params: {
      person: { first_name: "Updated" },
      return_to: "registration_link",
      event_registration_id: event_registration.id
    }

    expect(response).to redirect_to(link_organization_event_registration_path(event_registration))
  end

  it "preserves the linking page's own return_to on the way back" do
    patch person_path(person), params: {
      person: { first_name: "Updated" },
      return_to: "registration_link",
      event_registration_id: event_registration.id,
      link_org_return_to: "registrants"
    }

    expect(response).to redirect_to(link_organization_event_registration_path(event_registration, return_to: "registrants"))
  end

  it "redirects to the profile for a normal edit with no origin context" do
    patch person_path(person), params: { person: { first_name: "Updated" } }

    expect(response).to redirect_to(person_path(person))
  end
end
