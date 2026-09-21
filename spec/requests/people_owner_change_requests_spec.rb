require "rails_helper"

# Owner self-service profile editing is staged behind Person.owner_editing_enabled?.
# When it's on, an owner can edit their own profile but only *request* changes to
# the admin-only fields (primary email, affiliations), and the controller strips
# those from a crafted submission.
RSpec.describe "Owner change requests on the person edit form", type: :request do
  let(:owner_user) { create(:user, :with_person, email: "owner@example.com") }
  let(:person) { owner_user.person }
  let(:organization) { create(:organization, name: "Sunrise Center") }
  let!(:affiliation) do
    create(:affiliation, person: person, organization: organization, title: "Facilitator")
  end

  before do
    sign_in owner_user
    allow(Person).to receive(:owner_editing_enabled?).and_return(true)
  end

  describe "the edit form" do
    it "offers change-request links for the primary email, organization name, and affiliations" do
      get edit_person_path(person)

      expect(response).to be_successful
      expect(response.body).to include("field=primary_email")
      expect(response.body).to include("field=affiliation")
      expect(response.body).to include("field=organization_name")
    end

    it "shows the pending request (not a new-request link) once one exists for a field" do
      request = create(:profile_change_request, :primary_email, person: person,
                                                requested_by: owner_user, requested_value: "new@example.com")

      get edit_person_path(person)

      expect(response.body).to include("Change requested — pending review")
      expect(response.body).to include(edit_profile_change_request_path(request))
      expect(response.body).not_to include("field=primary_email")
    end
  end

  describe "PATCH update" do
    it "saves owner-editable fields but strips the locked primary email and affiliations" do
      patch person_path(person), params: {
        person: {
          bio: "Updated by the owner",
          email: "hacked@example.com",
          user_attributes: { id: owner_user.id, email: "hacked-user@example.com" },
          affiliations_attributes: { "0" => { id: affiliation.id, title: "Hacked Title" } }
        }
      }

      expect(person.reload.bio).to eq("Updated by the owner")
      expect(person.email).not_to eq("hacked@example.com")
      expect(owner_user.reload.email).to eq("owner@example.com")
      expect(affiliation.reload.title).to eq("Facilitator")
    end
  end
end
