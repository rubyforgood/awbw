require "rails_helper"

RSpec.describe "Public registration new page", type: :system do
  let(:event) do
    create(
      :event,
      :published,
      :publicly_visible,
      title: "My Event",
      start_date: 2.days.from_now.change(hour: 10),
      end_date: 2.days.from_now.change(hour: 12)
    )
  end

  before do
    driven_by(:rack_test)
    form = FormBuilderService.new(
      name: FormBuilderService::EXTENDED_REGISTRATION_FORM_NAME,
      sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
    ).call
    EventForm.create!(event: event, form: form, role: "registration")
  end

  describe "back to event link" do
    it "shows a back link to the event page" do
      visit new_event_public_registration_path(event)

      expect(page).to have_link("Back to Event", href: event_path(event))
    end
  end

  describe "event title link" do
    it "links the event title back to the event page" do
      visit new_event_public_registration_path(event)

      within("h1") do
        expect(page).to have_link(event.title, href: event_path(event))
      end
    end
  end
end
