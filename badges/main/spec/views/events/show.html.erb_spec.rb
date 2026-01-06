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
    assign(:event, event.decorate)
    allow(view).to receive(:current_user).and_return(build_stubbed(:user, super_user: true))
  end

  it "renders the event title" do
    render

    expect(rendered).to have_content("Test Event")
  end

  it "renders all event details" do
    render

    expect(rendered).to have_content("Test Event")
    expect(rendered).to have_content("This is a test event description")

    expect(rendered).to have_content("Jan 15")
    expect(rendered).to have_content("10 am")

    expect(rendered).to have_content("4 pm")

    expect(rendered).to have_content("Registration closed") # 2024 is in the past
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
    let(:formatted_event_start_time) do
      if event.start_date.min.zero?
        event.start_date.strftime("%-l %P")     # "1 am"
      else
        event.start_date.strftime("%-l:%M %P")  # "5:43 pm"
      end
    end

    it "handles minimal data gracefully" do
      render

      expect(rendered).to have_content("Minimal Event")
      expect(rendered).to have_content("Event with minimal data")
      expect(rendered).to include(event.start_date.strftime("%b %-d")) # "Oct 2"
      expect(rendered).to include(formatted_event_start_time)
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
    end
  end
end
