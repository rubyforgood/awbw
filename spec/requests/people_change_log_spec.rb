require "rails_helper"

RSpec.describe "People change log", type: :request do
  let(:person) { create(:person) }

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it_behaves_like "a page with a change log" do
      let(:record) { person }
      let(:page_path) { edit_person_path(person) }
    end
  end

  # The profile is admin-or-owner, but the change log is admin data — the owner
  # sees their own page without it.
  context "as the person themselves" do
    it "hides the change log" do
      user = create(:user, person: person)
      create(:ahoy_event, name: "update.person", resource_type: "Person", resource_id: person.id,
             properties: { resource_type: "Person", resource_id: person.id })
      sign_in user

      get edit_person_path(person)

      expect(response.body).not_to include("Change log")
    end
  end
end
