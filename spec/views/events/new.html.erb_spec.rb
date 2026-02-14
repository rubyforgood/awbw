require 'rails_helper'

RSpec.describe "events/new", type: :view do
  let(:event) { Event.new }
  let(:location) { create(:location, city: "My city") }

  before do
    assign(:event, event)
    assign(:locations, [ location ])
    assign(:sectors, [])
    assign(:categories_grouped, [])
    allow(view).to receive(:current_user).and_return(build_stubbed(:user, :admin))
    allow(view).to receive(:allowed_to?).and_return(true)
  end

  it "renders the new event heading" do
    render

    expect(rendered).to have_selector("h1", text: "New Event")
  end

  it "renders the form partial" do
    render

    expect(rendered).to have_selector("form")
  end

  it "renders the Cancel link" do
    render

    expect(rendered).to have_link("Cancel", href: events_path)
  end

  it "renders submit button" do
    render

    expect(rendered).to have_selector("input[type='submit']")
  end

  context "when event has errors" do
    let(:event) do
      event = Event.new
      event.errors.add(:title, "can't be blank")
      event.errors.add(:start_date, "can't be blank")
      event
    end

    it "renders error messages" do
      render

      expect(rendered).to have_selector(".errors")
    end
  end
end
