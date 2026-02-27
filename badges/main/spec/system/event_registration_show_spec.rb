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
    it "shows a back link to the event page" do
      sign_in(user)
      visit event_registration_path(registration)

      expect(page).to have_link("Back to Event", href: event_path(event))
    end
  end

  describe "event title link" do
    it "links the event title back to the event page" do
      sign_in(user)
      visit event_registration_path(registration)

      within("h2") do
        expect(page).to have_link(event.title, href: event_path(event))
      end
    end
  end

  describe "calendar links" do
    it "shows Add to Your Calendar header and calendar links" do
      sign_in(user)
      visit event_registration_path(registration)

      expect(page).to have_text("Add to Your Calendar")
      expect(page).to have_link("Google")
      expect(page).to have_link("Office 365")
    end
  end
end
