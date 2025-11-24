require 'rails_helper'

RSpec.describe "events/show", type: :view do
  let(:event) do
    create(:event,
           title: "Test Event",
           description: "This is a test event description",
           start_date: DateTime.new(2024, 1, 15, 10, 0),
           end_date: DateTime.new(2024, 1, 15, 16, 0),
           registration_close_date: DateTime.new(2024, 1, 10, 23, 59))
  end

  before do
    assign(:event, event)
    allow(view).to receive(:current_user).and_return(build_stubbed(:user, super_user: true))
  end

  it "renders the event title" do
    render

    expect(rendered).to have_content("Test Event")
  end

  it "renders all event details" do
    render

    expect(rendered).to have_content("Test Event")
    
    expect(rendered).to have_content("Description:")
    expect(rendered).to have_content("This is a test event description")
    
    expect(rendered).to have_content("Start Date:")
    expect(rendered).to have_content("January 15, 2024 10:00 AM")
    
    expect(rendered).to have_content("End Date:")
    expect(rendered).to have_content("January 15, 2024  4:00 PM")
    
    expect(rendered).to have_content("Registration Close Date:")
    expect(rendered).to have_content("January 10, 2024 11:59 PM")
  end

  it "renders action links" do
    render

    expect(rendered).to have_link("Edit", href: edit_event_path(event))
    expect(rendered).to have_link("Index", href: events_path)
  end

  context "when event has minimal data" do
    let(:event) do
      create(:event,
             title: "Minimal Event",
             description: "Event with minimal data",
             registration_close_date: nil)
    end

    it "handles minimal data gracefully" do
      render

      expect(rendered).to have_content("Minimal Event")
      expect(rendered).to have_content("Event with minimal data")
      expect(rendered).to include(event.start_date.strftime("%B %d, %Y")) # "October 02, 2025"
      expect(rendered).to include(event.start_date.strftime("%-l:%M %p")) # "5:43 PM"
    end
  end

  context "when event has empty description" do
    let(:event) do
      create(:event,
             title: "Event with Empty Description",
             description: "",
             start_date: 1.day.from_now,
             end_date: 2.days.from_now)
    end

    it "renders without description content" do
      render

      expect(rendered).to have_content(event.title)
      expect(rendered).to have_content("Description:")
    end
  end
end