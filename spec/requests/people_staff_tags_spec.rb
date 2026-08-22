require "rails_helper"

RSpec.describe "Person staff tags", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let!(:trainer_tag) { create(:staff_tag, name: "Potential future trainer") }
  let!(:cohort_tag) { create(:staff_tag, name: "DV Leadership Cohort") }

  def update_staff_tags(ids)
    patch person_path(person), params: {
      person: { first_name: person.first_name, staff_tag_ids: ids }
    }
  end

  describe "as an admin" do
    before { sign_in admin }

    it "renders the admin-only staff tags section on the edit form" do
      get edit_person_path(person)

      expect(response.body).to include("Staff tags")
      expect(response.body).to include("Potential future trainer")
      expect(response.body).to include("DV Leadership Cohort")
    end

    it "assigns staff tags and records who applied them" do
      update_staff_tags([ "", trainer_tag.id.to_s ])

      expect(person.reload.staff_tags).to contain_exactly(trainer_tag)
      expect(person.staff_taggings.first.created_by).to eq(admin)
    end

    it "clears staff tags when none are submitted" do
      person.staff_tags << cohort_tag
      update_staff_tags([ "" ])

      expect(person.reload.staff_tags).to be_empty
    end

    it "keeps an already-applied archived tag when the form re-submits it" do
      archived = create(:staff_tag, :archived, name: "Legacy roster")
      person.staff_tags << archived

      get edit_person_path(person)
      expect(response.body).to include("Legacy roster")

      update_staff_tags([ "", archived.id.to_s, trainer_tag.id.to_s ])
      expect(person.reload.staff_tags).to contain_exactly(archived, trainer_tag)
    end
  end

  describe "filtering the people index" do
    before { sign_in admin }

    it "returns only people carrying the selected staff tag" do
      tagged = create(:person, first_name: "Tagged", last_name: "Person")
      tagged.staff_tags << cohort_tag
      create(:person, first_name: "Untagged", last_name: "Person")

      get people_path(staff_tag_ids: cohort_tag.id), headers: { "Turbo-Frame" => "people_results" }

      expect(response.body).to include("Tagged")
      expect(response.body).not_to include("Untagged")
    end

    it "exposes the staff tag filter to admins" do
      get people_path
      expect(response.body).to include('name="staff_tag_ids"')
    end
  end
end
