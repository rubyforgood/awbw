require "rails_helper"

RSpec.describe "Public form pages", type: :system do
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
      name: "Extended Event Registration",
      sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
    ).call
    EventForm.create!(event: event, form: form, role: "registration")
  end

  def add_scholarship_form
    EventForm.create!(event: event, form: create(:form, :with_fields), role: "scholarship")
  end

  shared_examples "an event-linked public form" do |path_helper|
    it "shows a back link to the event page" do
      visit public_send(path_helper, event)
      expect(page).to have_link("Back to event", href: event_path(event))
    end

    it "links the event title back to the event page" do
      visit public_send(path_helper, event)
      within("h1") do
        expect(page).to have_link(event.title, href: event_path(event))
      end
    end
  end

  describe "registration_form" do
    it_behaves_like "an event-linked public form", :new_event_registration_form_path

    it "uses the Registration heading and submits to its own endpoint" do
      visit new_event_registration_form_path(event)

      expect(page).to have_css("h2", text: "Registration")
      expect(page).to have_css("form[action='#{event_registration_form_path(event)}']")
    end

    context "with a scholarship form available" do
      before { add_scholarship_form }

      it "hides the scholarship section by default" do
        visit new_event_registration_form_path(event)

        expect(page).to have_no_css("h3", text: "Scholarship application")
      end

      it "shows the scholarship section when scholarship_requested=true" do
        visit new_event_registration_form_path(event, scholarship_requested: true)

        expect(page).to have_css("h3", text: "Scholarship application")
      end
    end
  end

  describe "scholarship_form" do
    before { add_scholarship_form }

    it_behaves_like "an event-linked public form", :new_event_scholarship_form_path

    it "uses the Scholarship application heading and submits to its own endpoint" do
      visit new_event_scholarship_form_path(event)

      expect(page).to have_css("h2", text: "Scholarship application")
      expect(page).to have_css("form[action='#{event_scholarship_form_path(event)}']")
    end

    it "shows the scholarship section by default" do
      visit new_event_scholarship_form_path(event)

      expect(page).to have_css("h3", text: "Scholarship application")
    end
  end

  describe "bulk_payment_form" do
    it_behaves_like "an event-linked public form", :new_event_bulk_payment_form_path

    it "uses the Bulk payment heading and submits to its own endpoint" do
      visit new_event_bulk_payment_form_path(event)

      expect(page).to have_css("h2", text: "Bulk payment")
      expect(page).to have_css("form[action='#{event_bulk_payment_form_path(event)}']")
    end
  end
end
