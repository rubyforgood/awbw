require "rails_helper"

# The person's own profile page is where they go to edit or ask for changes
# (outside production, per PersonPolicy#edit_own_profile?).
RSpec.describe "A person's own profile as the place to edit", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:organization) { create(:organization, name: "Sunrise Center") }
  let!(:affiliation) { create(:affiliation, person: person, organization: organization, title: "Facilitator") }

  describe "viewing their own profile" do
    before { sign_in owner_user }

    it "shows the edit button and the ask-for-a-change buttons" do
      get person_path(person)

      expect(response.body).to include("This is your profile")
      expect(response.body).to include("Edit my profile")
      expect(response.body).to include("field=primary_email")
      expect(response.body).to include("field=affiliation")
      expect(response.body).to include(edit_person_path(person, anchor: "profile-preferences"))
    end

    it "offers to ask for a change on affiliations and to edit sectors" do
      get person_path(person)

      expect(response.body).to include("Ask for a change")
      expect(response.body).to include(edit_person_path(person, anchor: "sectors"))
    end

    it "prompts for a bio when there isn't one" do
      person.update!(bio: nil)

      get person_path(person)

      expect(response.body).to include("Add a bio")
      expect(response.body).to include(edit_person_path(person, anchor: "bio"))
    end

    it "lists pending change requests" do
      request = create(:profile_change_request, :primary_email, person: person,
                                                requested_by: owner_user, requested_value: "new@example.com")

      get person_path(person)

      expect(response.body).to include("AWBW staff are looking at your request")
      expect(response.body).to include("Primary email: new@example.com")
      expect(response.body).to include(edit_profile_change_request_path(request))
    end

    it "hides the banner in production" do
      allow(Rails.env).to receive(:production?).and_return(true)

      get person_path(person)

      expect(response.body).not_to include("This is your profile")
      expect(response.body).not_to include("Ask for a change")
    end
  end

  describe "an admin viewing someone else's profile" do
    before { sign_in create(:user, :admin) }

    it "shows the admin edit button but not the owner banner" do
      get person_path(person)

      expect(response.body).not_to include("This is your profile")
      expect(response.body).to include(edit_person_path(person))
      expect(response.body).to include(edit_person_path(person, anchor: "affiliations"))
      expect(response.body).not_to include("Ask for a change")
    end
  end

  describe "the edit page" do
    before { sign_in owner_user }

    it "leads back to the profile" do
      get edit_person_path(person)

      expect(response.body).to include("Edit my profile")
      expect(response.body).to match(/href="#{person_path(person)}"[^>]*>\s*<i[^>]*><\/i>\s*My profile/)
      expect(response.body).to match(/href="#{person_path(person)}"[^>]*>Cancel/)
    end
  end

  describe "sending a change request" do
    before { sign_in owner_user }

    it "returns to the profile" do
      post profile_change_requests_path(person_id: person), params: {
        profile_change_request: { field: "primary_email", requested_value: "new@example.com" }
      }

      expect(response).to redirect_to(person_path(person))
    end

    it "returns to the profile's affiliations after an affiliation request" do
      post profile_change_requests_path(person_id: person), params: {
        profile_change_request: {
          field: "affiliation", affiliation_id: affiliation.id,
          requested_value: "Title or role", proposed_title: "Lead facilitator"
        }
      }

      expect(response).to redirect_to(person_path(person, anchor: "affiliations"))
    end
  end
end
