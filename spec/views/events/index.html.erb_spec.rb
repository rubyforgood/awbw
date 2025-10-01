require 'rails_helper'

RSpec.describe "events/index", type: :view do
  before do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
  end

  let(:user) { create(:user, super_user: true) }
  let(:event_closed) { create(:event, title: "Event 1",
                              start_date: 1.day.from_now, end_date: 2.days.from_now,
                              publicly_visible: true,
                              registration_close_date: -3.days.from_now) }
  let(:event_open) { create(:event, title: "Event 2",
                            start_date: 3.days.from_now, end_date: 4.days.from_now,
                            registration_close_date: 5.days.from_now,
                            publicly_visible: true) }
  let(:event_open_2) { create(:event, title: "Event 2",
                            start_date: 3.days.from_now, end_date: 4.days.from_now,
                            registration_close_date: nil,
                            publicly_visible: true) }
  let(:events) { [event_open, event_open] }

  before do
    assign(:events, events)
    allow(view).to receive(:current_user).and_return(user)
  end

  it "renders each event with checkbox and details" do
    assign(:events, [event_open, event_open_2, event_closed])
    render

    events.each do |event|
      expect(rendered).to have_content(event.title)
      expect(rendered).to have_content(event.start_date.strftime("%B %d, %Y"))
      expect(rendered).to have_content(event.end_date.strftime("%B %d, %Y"))
    end

    # Only the open event should have a checkbox
    expect(rendered).to have_selector("input[type='checkbox'][id='event_ids_#{event_open.id}']")
    expect(rendered).to have_selector("input[type='checkbox'][id='event_ids_#{event_open_2.id}']")
    expect(rendered).not_to have_selector("input[type='checkbox'][id='event_ids_#{event_closed.id}']")
  end

  it "renders action links for each event" do
    render

    events.each do |event|
      expect(rendered).to have_link(event.title, href: event_path(event))
      expect(rendered).to have_link("Edit", href: edit_event_path(event))
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

  context "when no events exist" do
    let(:events) { [] }

    it "renders empty message" do
      render

      expect(rendered).to have_content("No events available")
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