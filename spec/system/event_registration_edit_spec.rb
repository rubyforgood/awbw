require "rails_helper"

RSpec.describe "Event registration edit page", type: :system do
  let(:admin) { create(:user, :with_person, super_user: true) }
  let(:event) { create(:event, :published, title: "Test Event") }
  let!(:registration) { create(:event_registration, event: event, registrant: admin.person) }

  describe "user account box" do
    it "shows the registrant's account status and links to the user and filtered notifications" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "User account") do
        expect(page).to have_text("Active")
        expect(page).to have_link("View account", href: user_path(admin))
        expect(page).to have_link("View notifications",
          href: notifications_path(email: registration.registrant.preferred_email))
      end
    end

    it "shows an empty state and no account link when the registrant has no user" do
      registration_without_user = create(:event_registration, event: event, registrant: create(:person, user: nil))

      sign_in(admin)
      visit edit_event_registration_path(registration_without_user)

      within("section", text: "User account") do
        expect(page).to have_text("No user account")
        expect(page).to have_link("View notifications")
        expect(page).not_to have_link("View account")
      end
    end
  end

  describe "payment & allocation history" do
    it "shows an empty state when there are no allocations" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Allocations") do
        expect(page).to have_link("$10.99 due")
        expect(page).to have_text("No payments or allocations recorded yet")
      end
    end

    it "lists each allocation with its source, amount, and a total" do
      payment = create(:payment, amount_cents: 1000, amount_cents_remaining: 1000)
      create(:allocation, source: payment, allocatable: registration, amount: 1000)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Allocations") do
        expect(page).to have_text("Cash")
        expect(page).to have_text("$10.00")
        expect(page).to have_text("Total paid")
      end
    end
  end

  describe "scholarship box" do
    it "offers an Add scholarship link and does not create one from the checkbox alone" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Scholarship") do
        expect(page).to have_link("Add scholarship")
        check "Requested"
        expect(page).to have_link("Add scholarship")
      end

      expect(registration.scholarships.count).to eq(0)
    end
  end

  describe "registration status box" do
    it "flags the status as unsaved when changed until the form is saved" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Registration status") do
        expect(page).to have_no_text("Unsaved")
        select "No show", from: "event_registration[status]"
        expect(page).to have_text("Unsaved")
      end
    end
  end

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
