require "rails_helper"

# Profiles open people to any signed-in user (never the public) and let a person
# edit their own profile everywhere but production (PersonPolicy#profiles_visible_to_users?).
# The test env is non-production, so these run with profiles on.
RSpec.describe "People with profiles enabled", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:published_person) do
    other = create(:person, profile_is_searchable: true)
    create(:affiliation, person: other, organization: create(:organization))
    other
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

    it "updates their time zone but ignores email types" do
      person.update!(email_type: "personal", email_2: "second@example.com", email_2_type: "work")

      patch person_path(person), params: { person: {
        email_type: "work",
        email_2_type: "personal",
        user_attributes: { id: owner_user.id, time_zone: "Hawaii" }
      } }

      expect(person.reload.email_type).to eq("personal")
      expect(person.email_2_type).to eq("work")
      expect(owner_user.reload.time_zone).to eq("Hawaii")
    end

    it "shows both emails read-only with their types, leaving the time zone editable" do
      person.update!(email_2: "second@example.com", email_2_type: "personal")

      get edit_person_path(person)

      expect(response.body).to include("second@example.com")
      expect(response.body).to include("(p)")
      expect(response.body).not_to include('name="person[email_2]"')
      expect(response.body).not_to include('name="person[email_2_type]"')
      expect(response.body).not_to include('name="person[email_type]"')
      expect(response.body).to include('name="person[user_attributes][time_zone]"')
    end

    it "changes their primary sector and primary age range" do
      old_sector = create(:sectorable_item, sectorable: person, is_primary: true)
      new_sector = create(:sectorable_item, sectorable: person, is_primary: false)
      age_category = create(:category, category_type: create(:category_type, name: "AgeRange"))
      age_range = create(:categorizable_item, categorizable: person, category: age_category, is_primary: false)

      patch person_path(person), params: { person: {
        sectorable_items_attributes: [
          { id: old_sector.id, sector_id: old_sector.sector_id, is_primary: false },
          { id: new_sector.id, sector_id: new_sector.sector_id, is_primary: true }
        ],
        age_range_categorizable_items_attributes: [ { id: age_range.id, category_id: age_category.id, is_primary: true } ]
      } }

      expect(person.reload.primary_sector).to eq(new_sector.sector)
      expect(age_range.reload.is_primary).to be(true)
    end

    it "shows the primary star but not the leader crown on sectors" do
      create(:sectorable_item, sectorable: person)

      get edit_person_path(person)

      expect(response.body).to include("person[sectorable_items_attributes][0][is_primary]")
      expect(response.body).not_to include("person[sectorable_items_attributes][0][is_leader]")
    end

    it "ignores admin-only fields a non-admin owner tries to submit" do
      original_code = person.filemaker_code
      original_email = person.email

      patch person_path(person), params: { person: {
        bio: "New bio",
        email: "hijacked@example.com",
        email_2: "hijacked-2@example.com",
        filemaker_code: "HACK-999",
        notes: "self-added note",
        racial_ethnic_identity: "self-set identity",
        sectorable_items_attributes: [ { sector_id: create(:sector).id, is_leader: true } ],
        staff_taggings_attributes: [ { staff_tag_id: create(:staff_tag).id } ],
        user_attributes: { id: owner_user.id, super_user: true }
      } }

      person.reload
      expect(person.bio).to eq("New bio")
      expect(person.email).to eq(original_email)
      expect(person.email_2).not_to eq("hijacked-2@example.com")
      expect(person.filemaker_code).to eq(original_code)
      expect(person.notes).not_to eq("self-added note")
      expect(person.racial_ethnic_identity).not_to eq("self-set identity")
      expect(person.sectorable_items.sole.is_leader).to be(false)
      expect(person.staff_taggings).to be_empty
      expect(owner_user.reload.super_user?).to be(false)
    end
  end

  describe "edit page headings" do
    it "uses owner-friendly section titles for the owner" do
      sign_in owner_user
      get edit_person_path(person)

      expect(response.body).to include("Sectors you work in")
      expect(response.body).to include("Mailing addresses")
      expect(response.body).to include("Portal communications")
    end

    it "keeps the admin section titles for an admin" do
      sign_in create(:user, :admin)
      get edit_person_path(person)

      expect(response.body).to include("Mailing addresses")
      expect(response.body).not_to include("Sectors you work in")
      expect(response.body).not_to include("Portal communications")
    end
  end
end
