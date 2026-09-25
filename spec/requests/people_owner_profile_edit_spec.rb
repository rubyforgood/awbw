require "rails_helper"

# The staging profiles toggle (PROFILES_ENABLED / Profiles.enabled?) opens people
# and organizations to any signed-in user (never the public) and lets a person
# edit their own profile. These specs exercise the flag-on path.
RSpec.describe "People with profiles enabled", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:published_person) do
    other = create(:person, profile_is_searchable: true)
    create(:affiliation, person: other, organization: create(:organization))
    other
  end

  around do |example|
    ENV["PROFILES_ENABLED"] = "true"
    example.run
    ENV.delete("PROFILES_ENABLED")
  end

  describe "viewing as a non-admin signed-in user" do
    before { sign_in create(:user) }

    it "renders the people index" do
      get people_path
      expect(response).to have_http_status(:ok)
    end

    it "renders a published person's profile" do
      get person_path(published_person)
      expect(response).to have_http_status(:ok)
    end

    it "still hides an unpublished person" do
      hidden = create(:person, profile_is_searchable: false)
      get person_path(hidden)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "the public (signed out) is still shut out" do
    it "redirects to sign in" do
      get person_path(published_person)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "owner editing their own profile" do
    before { sign_in owner_user }

    it "updates a profile-facing field" do
      patch person_path(person), params: { person: { bio: "Facilitator since 2015" } }

      expect(person.reload.bio).to eq("Facilitator since 2015")
    end

    it "ignores admin-only fields a non-admin owner tries to submit" do
      original_code = person.filemaker_code

      patch person_path(person), params: { person: {
        bio: "New bio",
        filemaker_code: "HACK-999",
        notes: "self-added note",
        staff_taggings_attributes: [ { staff_tag_id: create(:staff_tag).id } ],
        user_attributes: { id: owner_user.id, super_user: true }
      } }

      person.reload
      expect(person.bio).to eq("New bio")
      expect(person.filemaker_code).to eq(original_code)
      expect(person.notes).not_to eq("self-added note")
      expect(person.staff_taggings).to be_empty
      expect(owner_user.reload.super_user?).to be(false)
    end
  end
end
