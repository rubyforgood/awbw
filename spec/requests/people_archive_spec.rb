require "rails_helper"

RSpec.describe "People archiving and deletion", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "PATCH /people/:id/archive" do
    it "archives the person and their user" do
      person = create(:person)

      patch archive_person_path(person)

      expect(response).to redirect_to(person_path(person))
      expect(person.reload).to be_discarded
      expect(person.user.reload).to be_discarded
    end
  end

  describe "PATCH /people/:id/unarchive" do
    it "restores an archived person and their user" do
      person = create(:person)
      PersonArchivalService.new(person).archive!

      patch unarchive_person_path(person)

      expect(response).to redirect_to(person_path(person))
      expect(person.reload).to be_kept
      expect(person.user.reload).to be_kept
    end
  end

  describe "GET /people (archived filter)" do
    it "hides archived people by default and shows them when archived=true" do
      active = create(:person, first_name: "Active", last_name: "Person")
      archived = create(:person, first_name: "Archived", last_name: "Person")
      PersonArchivalService.new(archived).archive!

      get people_path, headers: { "Turbo-Frame" => "people_results" }
      expect(response.body).to include("Active Person")
      expect(response.body).not_to include("Archived Person")

      get people_path(archived: true), headers: { "Turbo-Frame" => "people_results" }
      expect(response.body).to include("Archived Person")
      expect(response.body).not_to include("Active Person")
    end
  end
end
