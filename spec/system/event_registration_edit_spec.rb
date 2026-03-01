require "rails_helper"

RSpec.describe "Event registration edit page", type: :system do
  let(:admin) { create(:user, :with_person, super_user: true) }
  let(:event) { create(:event, :published, title: "Test Event") }
  let!(:registration) { create(:event_registration, event: event, registrant: admin.person) }

  describe "delete button" do
    it "deletes the registration" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      accept_confirm("Are you sure you want to delete?") do
        click_on "Delete"
      end

      expect(page).to have_current_path(event_registrations_path)
      expect(page).to have_text("Registration deleted")
      expect(EventRegistration.exists?(registration.id)).to be false
    end
  end
end
