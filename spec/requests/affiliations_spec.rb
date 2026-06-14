require "rails_helper"

RSpec.describe "Affiliations", type: :request do
  let(:admin) { create(:user, :with_person, super_user: true) }
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:event) { create(:event) }
  let!(:registration) { create(:event_registration, event: event, registrant: person) }
  let!(:affiliation) { create(:affiliation, person: person, organization: organization, title: "Counselor") }

  describe "PATCH /affiliations/:id" do
    context "as an admin" do
      before { sign_in admin }

      it "updates the affiliation title and returns to the org-link editor" do
        patch affiliation_path(affiliation),
          params: { affiliation: { title: "Director" }, event_registration_id: registration.id, return_to: "registrants" }

        expect(affiliation.reload.title).to eq("Director")
        expect(response).to redirect_to(link_organization_event_registration_path(registration, return_to: "registrants"))
      end
    end

    context "as a regular user" do
      before { sign_in create(:user, :with_person) }

      it "is not authorized" do
        patch affiliation_path(affiliation), params: { affiliation: { title: "Director" } }

        expect(affiliation.reload.title).to eq("Counselor")
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
