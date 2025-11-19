require "rails_helper"

RSpec.describe "events/index", type: :view do
  let(:user) { create(:user, super_user: true) }
  let(:event_closed) {
    create(:event, title: "Event 1",
      start_date: 1.day.from_now, end_date: 2.days.from_now,
      publicly_visible: true,
      registration_close_date: -3.days.from_now)
  }
  let(:event_open) {
    create(:event, title: "Event 2",
      start_date: 3.days.from_now, end_date: 4.days.from_now,
      registration_close_date: 5.days.from_now,
      publicly_visible: true)
  }
  let(:event_open_2) {
    create(:event, title: "Event 2",
      start_date: 3.days.from_now, end_date: 4.days.from_now,
      registration_close_date: nil,
      publicly_visible: true)
  }
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
      formatted = event.decorate.times(display_day: true, display_date: true)
      text      = formatted.gsub("<br>", "")
      expect(rendered).to have_text(text)
    end
  end

  it "renders action links for each event" do
    render

    events.each do |event|
      expect(rendered).to have_content(event.title)
      expect(rendered).to have_link("Edit", href: edit_event_path(event))
    end
  end

  it "renders the New Event link" do
    render

    expect(rendered).to have_link("New Event", href: new_event_path)
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

      formatted = event_with_minimal_data.decorate.times(display_day: true, display_date: true)
      text      = formatted.gsub("<br>", "")
      expect(rendered).to have_text(text)
    end
  end
end

