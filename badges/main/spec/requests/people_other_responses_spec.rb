require "rails_helper"

RSpec.describe "Person Other form responses", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let(:form) { create(:form) }
  let(:submission) { create(:form_submission, person: person, form: form) }

  def answer(identifier, value)
    field = create(:form_field, form: form, field_identifier: identifier)
    create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
  end

  before { sign_in admin }

  describe "profile page" do
    it "shows the Other service area beside the sector tags" do
      person.update!(profile_show_sectors: true)
      answer("primary_service_area", "Other: Equine therapy")

      get person_path(person)

      expect(response.body).to include("Equine therapy")
    end
  end

  describe "edit page" do
    it "shows the Other service area in the sectors section" do
      answer("primary_service_area_single", "Other: Music therapy")

      get edit_person_path(person)

      expect(response.body).to include("Music therapy")
    end

    it "shows the Other workshop setting near the category checkboxes" do
      category_type = create(:category_type, :published, profile_specific: true)
      create(:category, :published, category_type: category_type)
      answer("workshop_environments", "Other: Equine center")

      get edit_person_path(person)

      expect(response.body).to include("Equine center")
    end
  end
end
