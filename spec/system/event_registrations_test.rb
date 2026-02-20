require "rails_helper"

RSpec.describe "Event Registration form", type: :system do
  let(:admin) { create(:user, :admin, :with_person) }
  let(:person_to_register) { create(:person, first_name: "Jane", last_name: "Smith", email: "jane@example.com") }
  let!(:event) { create(:event, :published, title: "Test Workshop", start_date: 2.days.from_now) }

  describe "GET /event_registrations/new" do
    context "when admin is logged in" do
      before do
        sign_in admin
        visit new_event_registration_path
      end

      it "shows the new event registration form" do
        expect(page).to have_content("New Event Registration")
        expect(page).to have_selector("select#event_registration_event_id")
        expect(page).to have_selector("select#event_registration_registrant_id")
      end
    end
  end

  describe "GET /event_registrations/:id/edit" do
    let!(:event_registration) { create(:event_registration, event: event, registrant: person_to_register) }

    context "when admin is logged in" do
      before do
        sign_in admin
        visit edit_event_registration_path(event_registration)
      end

      it "shows the edit event registration form" do
        expect(page).to have_content("Edit Event Registration")
        expect(page).to have_selector("select#event_registration_event_id")
        expect(page).to have_selector("select#event_registration_registrant_id")
      end
    end
  end

  describe "person search (remote select)", js: true do
    let!(:person1) { create(:person, first_name: "Alice", last_name: "Wonder", email: "alice@test.com") }
    let!(:person2) { create(:person, first_name: "Bob", last_name: "Builder", email: "bob@test.com") }

    before do
      sign_in admin
      visit new_event_registration_path
    end

    it "selects a person from search results and creates an event registration" do
      find(".ts-control").click
      fill_in "Registrant", with: "Alice"

      within(".ts-dropdown") do
        find(".option", text: "Alice Wonder").click
      end

      expect(find(".ts-control")).to have_content("Alice Wonder")
      find("#event_registration_event_id option[value='#{event.id}']").select_option
      click_button "Submit"

      expect(page).to have_content("Registration created")
    end
  end
end
