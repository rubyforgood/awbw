require "rails_helper"

RSpec.describe "Event registration edit page", type: :system do
  let(:admin) { create(:user, :with_person, super_user: true) }
  let(:event) { create(:event, :published, title: "Test Event") }
  let!(:registration) { create(:event_registration, event: event, registrant: admin.person) }

  describe "user account square" do
    it "links to the registrant's user account" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      expect(page).to have_link("User account", href: user_path(admin))
    end

    it "offers to create a user when the registrant has none" do
      registration_without_user = create(:event_registration, event: event, registrant: create(:person, user: nil))

      sign_in(admin)
      visit edit_event_registration_path(registration_without_user)

      expect(page).to have_link("Create user",
        href: new_user_path(person_id: registration_without_user.registrant_id, event_registration_id: registration_without_user.id))
    end
  end

  describe "payment & allocation history" do
    it "shows the cost/allocated/due totals with nothing allocated" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Registration allocations") do
        expect(page).to have_text(/registration cost/i)
        expect(page).to have_text(/amount allocated/i)
        expect(page).to have_text(/amount due/i)
        expect(page).to have_text("$10.99")
        expect(page).to have_text("$0.00")
      end
    end

    it "sums allocations into the amount allocated total (no line items)" do
      payment = create(:payment, amount_cents: 1000, amount_cents_remaining: 1000)
      create(:allocation, source: payment, allocatable: registration, amount: 1000)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Registration allocations") do
        expect(page).to have_text(/amount allocated/i)
        expect(page).to have_text("$10.00")
        expect(page).to have_no_text("Source")
      end
    end

    it "shows a fully-allocated state when the cost is fully allocated" do
      payment = create(:payment, amount_cents: 1099, amount_cents_remaining: 1099)
      create(:allocation, source: payment, allocatable: registration, amount: 1099)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Registration allocations") do
        expect(page).to have_text("Nothing")
      end
    end
  end

  describe "scholarship box" do
    it "offers an Add scholarship link and does not create one from the checkbox alone" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Scholarship") do
        expect(page).to have_link("Add scholarship")
        check "Requested", allow_label_click: true
        expect(page).to have_link("Add scholarship")
      end

      expect(registration.scholarships.count).to eq(0)
    end

    it "keeps the View jump link and shows the tasks-completed chip in the scholarship theme color at the bottom" do
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 1_000, tasks_completed: true)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Scholarship") do
        expect(page).to have_link("View", href: edit_scholarship_path(scholarship, return_to: "registration"))
        # Tasks-completed chip uses the scholarships theme (fuchsia), not green.
        expect(page).to have_css("span.bg-fuchsia-50.text-fuchsia-700", text: "Tasks completed")
        expect(page).to have_no_css("span.bg-green-50.text-green-700", text: "Tasks completed")
      end
    end
  end

  describe "registration status box" do
    it "flags the status as unsaved when changed until the form is saved" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      badge = "[data-attendance-status-target='dirty']"
      expect(page).to have_no_css(badge, visible: true)

      find("select[name='event_registration[status]']")
        .find(:option, "No show").select_option

      expect(page).to have_css(badge, visible: true, text: "Unsaved")
    end
  end

  describe "notifications box" do
    it "lists notifications sent to the registrant" do
      create(:notification,
             recipient_email: registration.registrant.preferred_email,
             email_subject: "Event registration confirmed")

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Registration communications") do
        expect(page).to have_text("Event registration confirmed")
        expect(page).to have_no_link("Event registration confirmed")
        expect(page).to have_link("View all")
      end
    end

    it "logs a notification inline, saved with the form" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Registration communications") do
        click_on "Add notification"
        fill_in "Subject", with: "Called about parking"
      end

      # Confirm the inline field registered its value before submitting, then wait
      # for the save round-trip to finish before checking the database.
      expect(page).to have_field("Subject", with: "Called about parking")
      click_on "Save changes"
      expect(page).to have_text("successfully updated")

      notification = registration.notifications.find_by(email_subject: "Called about parking")
      expect(notification).to be_present
      expect(notification.channel).to eq("email")
    end
  end

  describe "comments box" do
    it "keeps a newly added comment visible even past the first page" do
      create_list(:comment, 5, commentable: registration)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("#comments-section") do
        click_on "Add comment"
      end

      expect(page).to have_field("Type your comment")
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
