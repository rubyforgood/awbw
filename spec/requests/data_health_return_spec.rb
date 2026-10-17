require "rails_helper"

RSpec.describe "Returning to Data health from a check's row links", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let(:event_registration) { create(:event_registration, registrant: person) }
  let(:back) { { return_to: "data_health", check: "misaligned_affiliation_provenance" } }
  let(:reopened) do
    admin_data_health_path(open: "misaligned_affiliation_provenance", anchor: "check-misaligned_affiliation_provenance")
  end

  before { sign_in admin }

  it "gives the person edit page a Data health eyebrow that reopens the check" do
    get edit_person_path(person, **back)

    expect(response.body).to include(CGI.escapeHTML(reopened))
  end

  it "returns to Data health after saving the person" do
    patch person_path(person), params: { person: { first_name: "Updated" }, **back }

    expect(response).to redirect_to(reopened)
  end

  it "gives the Link organizations page a Data health eyebrow" do
    get link_organization_event_registration_path(event_registration, **back)

    expect(response.body).to include("Back to Data health")
    expect(response.body).to include(CGI.escapeHTML(reopened))
  end

  it "falls back to the plain page for an unknown check" do
    get edit_person_path(person, return_to: "data_health", check: "../etc")

    expect(response.body).to include(%(href="#{admin_data_health_path}"))
  end
end
