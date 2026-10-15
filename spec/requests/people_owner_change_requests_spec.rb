require "rails_helper"

# Owner self-service profile editing is on outside production (PersonPolicy's
# profiles_visible_to_users?). An owner can edit their own profile but only
# *request* changes to the admin-only fields (primary email, affiliations), which
# the policy's params_filter strips from a crafted submission.
RSpec.describe "Owner change requests on the person edit form", type: :request do
  let(:owner_user) { create(:user, :with_person, email: "owner@example.com") }
  let(:person) { owner_user.person }
  let(:organization) { create(:organization, name: "Sunrise Center") }
  let!(:affiliation) do
    create(:affiliation, person: person, organization: organization, title: "Facilitator")
  end

  before do
    sign_in owner_user
  end

  describe "the edit form" do
    it "offers change-request buttons for the emails and each affiliation, plus a free-text request" do
      get edit_person_path(person)

      expect(response).to be_successful
      expect(response.body).to include("field=primary_email")
      expect(response.body).to include("affiliation_id=#{affiliation.id}")
      expect(response.body).to include("field=other")
      expect(response.body).to include("AWBW Facilitator")
    end

    it "shows the secondary email as admin-editable with a change-request link, even when blank" do
      get edit_person_path(person)

      expect(response.body).to include("Secondary email")
      expect(response.body).to include("None yet")
      expect(response.body).to include("field=secondary_email")
    end

    it "shows an existing secondary email with its change-request link" do
      person.update!(email_2: "second@example.com")

      get edit_person_path(person)

      expect(response.body).to include("second@example.com")
      expect(response.body).to include("field=secondary_email")
    end

    it "shows the pending request (not a new-request link) once one exists for a field" do
      request = create(:profile_change_request, :primary_email, person: person,
                                                requested_by: owner_user, requested_value: "new@example.com")

      get edit_person_path(person)

      expect(response.body).to include("See your request")
      expect(response.body).to include("Change to #{request.requested_value} requested")
    end

    it "flags a specific affiliation that has a pending request, linking to it" do
      request = create(:profile_change_request, person: person, field: "affiliation",
                       affiliation: affiliation, requested_value: "Title or role",
                       proposed_title: "Lead Facilitator", details: nil)

      get edit_person_path(person)

      expect(response.body).to include("Change requested")
      expect(response.body).to include("See your request")
      # Organizations can still be added while one has a pending request.
      expect(response.body).to include("add=1")
      expect(request).to be_pending
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

    it "lets the owner pick their work address on an existing affiliation" do
      address = create(:address, addressable: organization)

      patch person_path(person), params: {
        person: { affiliations_attributes: { affiliation.id.to_s => { id: affiliation.id, organization_address_id: address.id } } }
      }

      expect(affiliation.reload.organization_address_id).to eq(address.id)
    end

    it "can't add an affiliation through the edit form" do
      expect {
        patch person_path(person), params: {
          person: { affiliations_attributes: { "0" => { organization_id: create(:organization).id, title: "Sneaky" } } }
        }
      }.not_to change(Affiliation, :count)
    end
  end
end
