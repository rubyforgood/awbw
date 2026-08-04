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

  describe "Linked organizations card" do
    let(:organization) { create(:organization, name: "Asian Women Shelter") }

    it "renders a linked organization as a profile link with a × removal toggle" do
      create(:event_registration_organization, event_registration: registration, organization: organization)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Linked organizations") do
        expect(page).to have_link("Asian Women Shelter", href: organization_path(organization))
        # The × is a <label for> wired to the (visually hidden) checkbox that
        # submits the link — unchecking it marks the org for removal on save.
        expect(page).to have_css("label[for='org_chip_#{organization.id}']")
        expect(page).to have_field("event_registration[organization_ids][]", type: "checkbox", with: organization.id.to_s, visible: :all)
      end
    end
  end

  describe "payment & allocation history" do
    it "shows the cost/allocated/due totals with nothing allocated" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Registration payments and allocations") do
        expect(page).to have_text(/registration cost/i)
        expect(page).to have_text(/amount allocated/i)
        expect(page).to have_text(/amount due/i)
        expect(page).to have_text("$10.99")
        expect(page).to have_text("$0")
      end
    end

    it "sums allocations into the amount allocated total (no line items)" do
      payment = create(:payment, amount_cents: 1000, amount_cents_remaining: 1000)
      create(:allocation, source: payment, allocatable: registration, amount: 1000)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Registration payments and allocations") do
        expect(page).to have_text(/amount allocated/i)
        expect(page).to have_text("$10")
        expect(page).to have_no_text("Source")
      end
    end

    it "shows a fully-allocated state when the cost is fully allocated" do
      payment = create(:payment, amount_cents: 1099, amount_cents_remaining: 1099)
      create(:allocation, source: payment, allocatable: registration, amount: 1099)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Registration payments and allocations") do
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

    it "keeps the Edit jump link and shows the tasks-completed chip in the scholarship theme color at the bottom" do
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 1_000, tasks_completed: true)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Scholarship") do
        expect(page).to have_link("Edit", href: edit_scholarship_path(scholarship, return_to: "registration"))
        # Tasks-completed chip uses the scholarships theme (fuchsia), not green.
        expect(page).to have_css("span.bg-fuchsia-50.text-fuchsia-700", text: "Tasks completed")
        expect(page).to have_no_css("span.bg-green-50.text-green-700", text: "Tasks completed")
      end
    end

    it "shows an orange tasks-outstanding chip when the scholarship's tasks are incomplete" do
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 1_000, tasks_completed: false)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Scholarship") do
        expect(page).to have_css("span.bg-amber-50.text-amber-700", text: "Tasks outstanding")
        expect(page).to have_no_css("span", text: "Tasks completed")
      end
    end

    it "links the grant's organization funder to its profile" do
      organization = create(:organization, name: "Acme Foundation")
      grant = create(:grant, donor: organization)
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 1_000, grant: grant)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Scholarship") do
        expect(page).to have_text("Grantor:")
        expect(page).to have_link("Acme Foundation", href: organization_path(organization))
      end
    end

    it "links the grant's person funder to its profile" do
      funder = create(:person, first_name: "Dana", last_name: "Donor")
      grant = create(:grant, :donated_by_person, donor: funder)
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 1_000, grant: grant)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Scholarship") do
        expect(page).to have_link(funder.full_name, href: person_path(funder))
      end
    end

    it "shows no grantor text (just a spacer) when the scholarship has no grant" do
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 1_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Scholarship") do
        expect(page).to have_no_text("Grantor:")
      end
    end
  end

  describe "shout out box" do
    it "stores the shout-out text on the registrant and flags the registration when saved" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      within("section", text: "Shout out") do
        fill_in "Shout-out text", with: "Grateful to bring art to the survivors we serve."
        check "Feature on the recipients page", allow_label_click: true
      end

      click_on "Save changes"

      expect(page).to have_current_path(registrants_event_path(event, highlight: registration.id))
      expect(registration.reload.shoutout).to be(true)
      expect(registration.registrant.reload.shoutout_text).to eq("Grateful to bring art to the survivors we serve.")
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

  describe "per-day attendance checkboxes" do
    it "renders a checkbox per event day, reflecting stored state, and persists changes" do
      registration.update!(completed_day_1: true)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      # The event spans 3 days, so Days 1-3 show (and no Day 4).
      expect(page).to have_field("Day 1", checked: true)
      expect(page).to have_field("Day 2", checked: false)
      expect(page).to have_field("Day 3", checked: false)
      expect(page).to have_no_field("Day 4")

      check "Day 2", allow_label_click: true
      click_on "Save changes"

      expect(page).to have_current_path(registrants_event_path(event, highlight: registration.id))
      expect(registration.reload.completed_day_1).to be(true)
      expect(registration.completed_day_2).to be(true)
    end

    it "derives the attendance status from the checked days and saves both together" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      badge = "[data-attendance-status-target='dirty']"
      expect(page).to have_no_css(badge, visible: true)

      # Checking every day rolls the status forward to Attended (mirrors onboarding).
      check "Day 1", allow_label_click: true
      check "Day 2", allow_label_click: true
      check "Day 3", allow_label_click: true

      expect(page).to have_css(badge, visible: true, text: "Unsaved")
      expect(page).to have_select("event_registration[status]", selected: "Attended")

      click_on "Save changes"

      # Wait for the save round-trip to land before reading the database.
      expect(page).to have_current_path(registrants_event_path(event, highlight: registration.id))
      expect(registration.reload.status).to eq("attended")
      expect(registration.completed_day_count).to eq(3)
    end

    it "leaves an inactive status untouched when days are toggled" do
      registration.update!(status: "cancelled")

      sign_in(admin)
      visit edit_event_registration_path(registration)

      check "Day 1", allow_label_click: true

      # Cancelled is a deliberate manual state, so toggling a day never overrides it.
      expect(page).to have_select("event_registration[status]", selected: "Cancelled")
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
        click_on "Add communication"
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

  describe "Organizations / scholarship / CE row visibility" do
    it "shows scholarship (paid) and hides CE (no hours), widening organizations to two columns" do
      sign_in(admin)
      visit edit_event_registration_path(registration)

      expect(page).to have_css("h2", text: "Scholarship")
      expect(page).to have_no_css("h2", text: "Continuing education")
      expect(page).to have_css("section.sm\\:col-span-2", text: "organizations")
    end

    it "shows scholarship and CE for a paid, CE-eligible event with organizations at one column" do
      event.update!(ce_hours_offered: 6)
      sign_in(admin)
      visit edit_event_registration_path(registration)

      expect(page).to have_css("h2", text: "Scholarship")
      expect(page).to have_css("h2", text: "Continuing education")
      expect(page).to have_css("section.sm\\:col-span-1", text: "organizations")
    end

    it "hides the scholarship box for a free event" do
      event.update!(cost_cents: 0, ce_hours_offered: 6)
      sign_in(admin)
      visit edit_event_registration_path(registration)

      expect(page).to have_no_css("h2", text: "Scholarship")
      expect(page).to have_css("h2", text: "Continuing education")
      expect(page).to have_css("section.sm\\:col-span-2", text: "organizations")
    end

    it "still shows the scholarship box when a scholarship was awarded before the event became free" do
      scholarship = create(:scholarship, recipient: registration.registrant, amount_cents: 1_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)
      event.update!(cost_cents: 0)

      sign_in(admin)
      visit edit_event_registration_path(registration)

      expect(page).to have_css("h2", text: "Scholarship")
    end

    it "fills the full row with organizations for a free event with no CE hours" do
      event.update!(cost_cents: 0)
      sign_in(admin)
      visit edit_event_registration_path(registration)

      expect(page).to have_no_css("h2", text: "Scholarship")
      expect(page).to have_no_css("h2", text: "Continuing education")
      expect(page).to have_css("section.sm\\:col-span-3", text: "organizations")
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
