require "rails_helper"

RSpec.describe "Person Other form responses", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  describe "profile page" do
    it "shows the Other sector as a free-text chip, not the primary sector" do
      person.update!(profile_show_sectors: true)
      create(:other_response, owner: person, kind: "sector", text: "Equine therapy")

      get person_path(person)

      expect(response.body).to include("Equine therapy")
      # The combined Sectors list renders it via the free-text "(other)" chip rather
      # than promoting it to the starred primary sector.
      equine_chip = response.body[/Equine therapy.{0,80}/m]
      expect(equine_chip).to include("(other)")
    end

    it "hides a dismissed Other sector" do
      person.update!(profile_show_sectors: true)
      create(:other_response, :dismissed, owner: person, kind: "sector", text: "Equine therapy")

      get person_path(person)

      expect(response.body).not_to include("Equine therapy")
    end
  end

  describe "edit page" do
    it "shows the Other sector with a dismiss control and a link into the review queue" do
      response_record = create(:other_response, owner: person, text: "Music therapy")

      get edit_person_path(person)

      expect(response.body).to include("Music therapy")
      expect(response.body).to include("Dismiss this response")
      # The chip deep-links into the review queue, anchored to its row, so the
      # admin can approve (promote/keep) or dismiss it there.
      expect(response.body).to include("#{other_responses_path}?")
      expect(response.body).to include("return_to=person_edit")
      expect(response.body).to include(response_record.review_anchor)
    end
  end
end
