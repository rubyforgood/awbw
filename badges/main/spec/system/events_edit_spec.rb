require "rails_helper"

RSpec.describe "Event edit form", type: :system do
  let(:admin) { create(:user, :with_person, :admin) }
  let(:event) { create(:event, title: "Original Title") }

  before { driven_by(:rack_test) }

  context "when another event has a registration form" do
    before do
      other_event = create(:event)
      create(:form, owner: other_event, name: "Public Registration")
    end

    it "allows admin to save changes to an existing event" do
      sign_in(admin)
      visit edit_event_path(event)

      fill_in "event_title", with: "Updated Title"
      click_button "Save changes"

      expect(page).to have_text("Event was successfully updated.")
      expect(page).to have_text("Updated Title")
    end
  end
end
