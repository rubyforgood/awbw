require "rails_helper"

RSpec.describe "Event registration show page", type: :system do
  let(:user) { create(:user, :with_person, time_zone: "Pacific Time (US & Canada)") }

  let(:event) do
    create(
      :event,
      :published,
      title: "My Event",
      start_date: 2.days.from_now.change(hour: 10),
      end_date: 2.days.from_now.change(hour: 12)
    )
  end

  let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

  before { driven_by(:rack_test) }

  describe "back to event link" do
    it "shows a back link to the event page with reg param" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_link("Back to event", href: event_path(event, reg: registration.slug))
    end
  end

  describe "event title link" do
    it "links the event title back to the event page with reg param" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      within("h2") do
        expect(page).to have_link(event.title, href: event_path(event, reg: registration.slug))
      end
    end
  end

  describe "calendar links" do
    it "shows Add to Your Calendar header and calendar links" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_text("Add to Your Calendar")
      expect(page).to have_link("Google")
      expect(page).to have_link("Office 365")
    end
  end

  describe "view registration form link" do
    it "links to form show with slug param" do
      FormBuilderService.new(
        name: "Extended Event Registration",
        sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
      ).call.tap { |form| EventForm.create!(event: event, form: form, role: "registration") }
      form = event.registration_form
      form.form_submissions.create!(person: user.person)

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_link("View registration details",
        href: event_registration_form_path(event, reg: registration.slug))
    end
  end

  describe "action links" do
    it "shows resend and cancel for active registration" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_button("Resend confirmation email")
      expect(page).to have_button("Cancel registration")
    end

    it "hides resend and cancel for cancelled registration" do
      registration.update!(status: "cancelled")

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).not_to have_button("Resend confirmation email")
      expect(page).not_to have_button("Cancel registration")
    end
  end

  describe "cancelled registration" do
    before { registration.update!(status: "cancelled") }

    it "shows Registration cancelled badge and Register again button" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_text("Registration cancelled")
      expect(page).to have_button("Register again")
    end

    it "does not show Register again when registration is closed" do
      event.update!(registration_close_date: 1.day.ago)

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_text("Registration cancelled")
      expect(page).not_to have_button("Register again")
    end
  end

  describe "guest access" do
    it "allows guests to view the ticket via slug" do
      visit registration_ticket_path(registration.slug)

      expect(page).to have_text("Event registration")
      expect(page).to have_text(registration.registrant.full_name)
    end
  end
end
