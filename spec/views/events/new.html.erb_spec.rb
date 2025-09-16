require 'rails_helper'

RSpec.describe "events/new", type: :view do
  let(:event) { Event.new }

  before do
    assign(:event, event)
  end

  it "renders the new event heading" do
    render

    expect(rendered).to have_selector("h1", text: "New Event")
  end

  it "renders the form partial" do
    render

    expect(rendered).to have_selector("form")
    expect(rendered).to have_selector("input[type='text'][name='event[title]']")
    expect(rendered).to have_selector("textarea[name='event[description]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[start_date]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[end_date]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[registration_close_date]']")
    expect(rendered).to have_selector("input[type='checkbox'][name='event[publicly_visible]']")
  end

  it "renders the Back link" do
    render

    expect(rendered).to have_link("Back", href: events_path)
  end

  it "renders submit button" do
    render

    expect(rendered).to have_selector("button[type='submit']")
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

      expect(rendered).to have_selector(".form-group")
    end
  end
end