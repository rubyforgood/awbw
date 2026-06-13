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

  def add_form(role, **attrs)
    EventForm.create!(event: event, form: create(:form, :standalone, :with_fields, **attrs), role: role)
  end

  shared_examples "an event-linked public form" do
    it "shows a back link and links the title to the event" do
      visit path
      expect(page).to have_link("Back to event", href: event_path(event))
      within("h1") { expect(page).to have_link(event.title, href: event_path(event)) }
    end
  end

  describe "registration lane" do
    let(:path) { new_event_form_path(event, "registration") }
    it_behaves_like "an event-linked public form"

    it "uses the Registration heading and submits to its own endpoint" do
      visit path
      expect(page).to have_css("h2", text: "Registration")
      expect(page).to have_css("form[action='#{event_form_path(event, "registration")}']")
    end

    it "does not show the scholarship section" do
      add_form("scholarship")
      visit path
      expect(page).to have_no_css("h3", text: "Scholarship application")
    end
  end

  describe "scholarship lane (registration + scholarship)" do
    before { add_form("scholarship") }
    let(:path) { new_event_form_path(event, "scholarship") }
    it_behaves_like "an event-linked public form"

    it "uses the Scholarship heading, shows the scholarship section, and submits to its endpoint" do
      visit path
      expect(page).to have_css("h2", text: "Scholarship application")
      expect(page).to have_css("h3", text: "Scholarship application")
      expect(page).to have_css("form[action='#{event_form_path(event, "scholarship")}']")
    end
  end

  describe "scholarship form header" do
    before do
      EventForm.create!(event: event, role: "scholarship",
                        form: create(:form, :standalone, :scholarship, :with_fields,
                                     header: "<p>Scholarship intro for {{event_month_year}}.</p>"))
    end

    it "renders the scholarship form header above the questions" do
      visit new_event_form_path(event, "scholarship")
      expect(page).to have_text("Scholarship intro for #{event.start_date.strftime("%B %Y")}.")
    end
  end

  describe "general lane" do
    before { add_form("general") }
    let(:path) { new_event_form_path(event, "general") }
    it_behaves_like "an event-linked public form"

    it "uses the General heading and submits to its own endpoint" do
      visit path
      expect(page).to have_css("h2", text: "General")
      expect(page).to have_css("form[action='#{event_form_path(event, "general")}']")
    end
  end

  describe "scholarship_questions lane (standalone, attaches to an existing registration)" do
    let(:person) { create(:user, :with_person).person }
    let!(:registration) { create(:event_registration, event: event, registrant: person) }
    before { add_form("scholarship") }

    it "renders the scholarship questions for an existing registration" do
      visit new_event_form_path(event, "scholarship_questions", reg: registration.slug)

      expect(page).to have_css("h2", text: "Scholarship application")
      expect(page).to have_css("form[action='#{event_form_path(event, "scholarship_questions", reg: registration.slug)}']")
    end

    it "redirects to the event when there is no registration to attach to" do
      visit new_event_form_path(event, "scholarship_questions")
      expect(page).to have_current_path(event_path(event))
    end
  end

  describe "ce_questions lane (standalone, attaches to an existing registration)" do
    let(:person) { create(:user, :with_person).person }
    let!(:registration) { create(:event_registration, event: event, registrant: person) }
    before { add_form("ce_credit") }

    it "renders the CE questions for an existing registration" do
      visit new_event_form_path(event, "ce_questions", reg: registration.slug)

      expect(page).to have_css("h2", text: "Continuing education credit")
      expect(page).to have_css("form[action='#{event_form_path(event, "ce_questions", reg: registration.slug)}']")
    end
  end
end
