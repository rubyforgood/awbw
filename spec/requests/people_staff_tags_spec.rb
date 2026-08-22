require "rails_helper"

RSpec.describe "Person staff tags", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let!(:trainer_tag) { create(:staff_tag, name: "Potential future trainer") }
  let!(:cohort_tag) { create(:staff_tag, name: "DV Leadership Cohort") }

  def set_staff_taggings(attrs)
    patch person_path(person), params: {
      person: { first_name: person.first_name, staff_taggings_attributes: attrs }
    }
  end

  describe "as an admin" do
    before { sign_in admin }

    it "renders the admin-only staff tags chip picker on the edit form" do
      get edit_person_path(person)

      expect(response.body).to include("Staff tags")
      expect(response.body).to include("Add staff tag")
      # The active tags are offered in the add-a-chip select.
      expect(response.body).to include("Potential future trainer")
      expect(response.body).to include("DV Leadership Cohort")
    end

    it "assigns staff tags via nested attributes and records who applied them" do
      set_staff_taggings([ { staff_tag_id: trainer_tag.id } ])

      expect(person.reload.staff_tags).to contain_exactly(trainer_tag)
      expect(person.staff_taggings.first.created_by).to eq(admin)
    end

    it "removes a staff tag when the chip is marked for destruction" do
      tagging = person.staff_taggings.create!(staff_tag: cohort_tag)
      set_staff_taggings([ { id: tagging.id, staff_tag_id: cohort_tag.id, _destroy: "1" } ])

      expect(person.reload.staff_tags).to be_empty
    end

    it "shows and keeps an already-applied unpublished tag" do
      unpublished = create(:staff_tag, :unpublished, name: "Legacy roster")
      unpublished_tagging = person.staff_taggings.create!(staff_tag: unpublished)

      get edit_person_path(person)
      expect(response.body).to include("Legacy roster")

      set_staff_taggings([
        { id: unpublished_tagging.id, staff_tag_id: unpublished.id },
        { staff_tag_id: trainer_tag.id }
      ])
      expect(person.reload.staff_tags).to contain_exactly(unpublished, trainer_tag)
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

    it "pre-selects the clicked staff tag in the filter dropdown" do
      get people_path(staff_tag_ids: cohort_tag.id)

      expect(response.body).to include('name="staff_tag_ids"')
      expect(response.body).to match(/value="#{cohort_tag.id}"[^>]*\bselected\b|\bselected\b[^>]*value="#{cohort_tag.id}"/)
    end

    it "shows a back-to-staff-tag eyebrow when opened from a tag's roster link" do
      get people_path(staff_tag_ids: cohort_tag.id, return_to: "staff_tag")

      expect(response.body).to include(staff_tag_path(cohort_tag))
      expect(response.body).to include("DV Leadership Cohort")
    end

    it "shows a back-to-staff-tags eyebrow when opened from the staff tags index" do
      get people_path(staff_tag_ids: cohort_tag.id, return_to: "staff_tags")

      expect(response.body).to include("← Staff tags")
      expect(response.body).to include(staff_tags_path)
    end
  end
end
