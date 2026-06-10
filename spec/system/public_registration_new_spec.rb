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
      name: "Extended Event Registration",
      subsections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
    ).call
    EventForm.create!(event: event, form: form, role: "registration")
  end

  describe "back to event link" do
    it "shows a back link to the event page" do
      visit new_event_public_registration_path(event)

      expect(page).to have_link("Back to event", href: event_path(event))
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

  describe "scholarship section" do
    let(:scholarship_form) do
      create(:form, :standalone, :scholarship, name: "Financial aid request",
             header: "<p>Scholarship intro for {{event_month_year}}.</p>")
    end

    before do
      create(:form_field, form: scholarship_form, answer_type: :group_header,
             name: "Eligibility questions", position: 1)
      create(:form_field, form: scholarship_form,
             name: "Why do you need a scholarship?", position: 2)
      create(:form_field, form: scholarship_form, answer_type: :group_header,
             name: "Financial details", position: 3)
      create(:form_field, form: scholarship_form,
             name: "Annual household income", position: 4)
      EventForm.create!(event: event, form: scholarship_form, role: "scholarship")
    end

    it "titles the section with the scholarship form's name" do
      visit new_event_public_registration_path(event, scholarship_requested: true)

      expect(page).to have_css("i.fa-hand-holding-heart")
      expect(page).to have_text("Financial aid request")
    end

    it "renders the scholarship form's header above the scholarship questions" do
      visit new_event_public_registration_path(event, scholarship_requested: true)

      expect(page).to have_text("Scholarship intro for #{event.start_date.strftime("%B %Y")}.")
    end

    it "renders the scholarship form's section headers from the form" do
      visit new_event_public_registration_path(event, scholarship_requested: true)

      expect(page).to have_text("Eligibility questions")
      expect(page).to have_text("Financial details")
    end

    it "does not repeat a section header that matches the form name" do
      scholarship_form.update!(name: "Eligibility questions")

      visit new_event_public_registration_path(event, scholarship_requested: true)

      within(".bg-blue-50\\/50") do
        expect(page).to have_text("Eligibility questions", count: 1)
      end
    end
  end
end
