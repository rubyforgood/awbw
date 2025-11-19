require 'rails_helper'

RSpec.describe "events/new", type: :view do
  let(:event) { Event.new }

  before do
    assign(:event, event)
    allow(view).to receive(:current_user).and_return(build_stubbed(:user, super_user: true))
  end

  it "renders the new event heading" do
    render

    expect(rendered).to have_selector("h1", text: "New Event")
  end

  it "renders the form partial" do
    render

    expect(rendered).to have_selector("form")
    expect(rendered).to have_field("event[title]")
    expect(rendered).to have_selector("textarea[name='event[description]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[start_date]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[end_date]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[registration_close_date]']")
    expect(rendered).to have_selector("input[type='checkbox'][name='event[publicly_visible]']")
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