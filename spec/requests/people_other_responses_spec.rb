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
    it "shows the Other sector as a free-text chip, not the primary sector" do
      person.update!(profile_show_sectors: true)
      create(:other_response, person: person, kind: "sector", text: "Equine therapy")

      get person_path(person)

      expect(response.body).to include("Equine therapy")
      # The combined Sectors list renders it via the free-text "(other)" chip rather
      # than promoting it to the starred primary sector.
      equine_chip = response.body[/Equine therapy.{0,80}/m]
      expect(equine_chip).to include("(other)")
    end

    it "hides a dismissed Other sector" do
      person.update!(profile_show_sectors: true)
      create(:other_response, :dismissed, person: person, kind: "sector", text: "Equine therapy")

      get person_path(person)

      expect(response.body).not_to include("Equine therapy")
    end
  end

  describe "edit page" do
    it "shows the Other sector in the sectors section with a dismiss control" do
      create(:other_response, person: person, kind: "sector", text: "Music therapy")

      get edit_person_path(person)

      expect(response.body).to include("Music therapy")
      expect(response.body).to include("Hide this response from the profile")
    end

    it "shows the Other workshop setting near the category checkboxes" do
      category_type = create(:category_type, :published, profile_specific: true)
      create(:category, :published, category_type: category_type)
      answer("primary_age_group", "Other: Toddlers")

      get edit_person_path(person)

      expect(response.body).to include("Toddlers")
    end
  end
end
