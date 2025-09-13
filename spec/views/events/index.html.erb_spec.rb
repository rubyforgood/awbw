require 'rails_helper'

RSpec.describe "events/index", type: :view do
  before do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
  end

  let(:user) { create(:user) }
  let(:event1) { create(:event, title: "Event 1", start_date: 1.day.from_now, end_date: 2.days.from_now) }
  let(:event2) { create(:event, title: "Event 2", start_date: 3.days.from_now, end_date: 4.days.from_now) }
  let(:events) { [event1, event2] }

  before do
    assign(:events, events)
    allow(view).to receive(:current_user).and_return(user)
  end

  it "renders the events table with proper headers" do
    render

    expect(rendered).to have_selector("th", text: "")
    expect(rendered).to have_selector("th", text: "Title")
    expect(rendered).to have_selector("th", text: "Start Date")
    expect(rendered).to have_selector("th", text: "End Date")
    expect(rendered).to have_selector("th", text: "Actions")
  end

  it "renders each event with checkbox and details" do
    render

    events.each do |event|
      expect(rendered).to have_selector("input[type='checkbox'][value='#{event.id}']")
      expect(rendered).to have_content(event.title)
      expect(rendered).to have_content(event.start_date.strftime("%B %d, %Y"))
      expect(rendered).to have_content(event.end_date.strftime("%B %d, %Y"))
    end
  end

  it "renders action links for each event" do
    render

    events.each do |event|
      expect(rendered).to have_link("Show", href: event_path(event))
      expect(rendered).to have_link("Edit", href: edit_event_path(event))
      expect(rendered).to have_link("Destroy", href: event_path(event))
    end
  end

  it "renders the bulk registration form" do
    render

    expect(rendered).to have_selector("form[action='#{bulk_create_event_registrations_path}'][method='post']")
    expect(rendered).to have_selector("input[type='submit'][value='Register for Selected Events']")
    expect(rendered).to have_selector("input[type='submit'][disabled='disabled']")
  end

  it "renders the New Event link" do
    render

    expect(rendered).to have_link("New Event", href: new_event_path)
  end

  it "includes JavaScript for checkbox handling" do
    render

    expect(rendered).to have_content("event-checkbox")
    expect(rendered).to have_content("register-button")
    expect(rendered).to have_content("addEventListener")
  end

  it "displays notice if present" do
    flash[:notice] = "Test notice"
    render

    expect(rendered).to have_selector("p#notice", text: "Test notice")
  end

  context "when no events exist" do
    let(:events) { [] }

    it "renders empty table" do
      render

      expect(rendered).to have_selector("table")
      expect(rendered).to have_selector("th", text: "Title")
      expect(rendered).not_to have_selector("input[type='checkbox']")
    end
  end

  context "when events have minimal data" do
    let(:event_with_minimal_data) { create(:event, title: "Minimal Event", description: nil) }
    let(:events) { [event_with_minimal_data] }

    it "handles minimal data gracefully" do
      render

      expect(rendered).to have_content("Minimal Event")
      expect(rendered).to have_content(event_with_minimal_data.start_date.strftime("%B %d, %Y"))
    end
  end
end