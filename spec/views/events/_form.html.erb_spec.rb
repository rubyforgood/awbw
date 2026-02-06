require 'rails_helper'

RSpec.describe "events/_form", type: :view do
  let(:event) { create(:event, title: "Original Title") }

  before do
    assign(:event, event)
    allow(view).to receive(:current_user).and_return(build_stubbed(:user, :admin))
    allow(view).to receive(:allowed_to?).with(:manage?, event).and_return(true)
    allow(view).to receive(:allowed_to?).with(:destroy?, event).and_return(true)
  end

  it "renders all form fields" do
    render

    expect(rendered).to have_selector("form")
    expect(rendered).to have_field("event[title]", with: "Original Title")
    expect(rendered).to have_selector("#event_rhino_description[type='hidden']", visible: :all)
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[start_date]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[end_date]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[registration_close_date]']")
    expect(rendered).to have_selector("input[type='checkbox'][name='event[published]']")
  end

  it "renders all form labels" do
    render

    expect(rendered).to have_selector("label", text: "Event title")
    expect(rendered).to have_selector("label", text: "Event Cost")
    expect(rendered).to have_selector("label", text: "Start time")
    expect(rendered).to have_selector("label", text: "End time")
    expect(rendered).to have_selector("label", text: "Registration close time")
    expect(rendered).to have_selector("label", text: "Published")
  end

  it "renders submit button" do
    render

    expect(rendered).to have_selector("input[type='submit']")
  end

  context "when event has existing data" do
    let(:event) do
      create(:event,
             title: "Existing Event",
             description: "Existing description",
             start_date: DateTime.new(2024, 1, 15, 10, 0),
             end_date: DateTime.new(2024, 1, 15, 16, 0),
             registration_close_date: DateTime.new(2024, 1, 10, 23, 59),
             published: true)
    end

    it "populates form fields with existing data" do
      render

      expect(rendered).to have_field("event[title]", with: "Existing Event")

      expect(rendered).to have_selector("input[name='event[published]']")
      expect(rendered).to have_selector("input[name='event[published]'][checked]")
    end
  end

  context "when event has validation errors" do
    let(:event) do
      event = Event.new
      event.errors.add(:title, "can't be blank")
      event.errors.add(:start_date, "can't be blank")
      event.errors.add(:end_date, "can't be blank")
      event
    end

    it "renders error messages" do
      render

      expect(rendered).to have_content("can't be blank")
    end
  end

  context "when event has no errors" do
    it "does not render error messages" do
      render

      expect(rendered).not_to have_selector(".error")
      expect(rendered).not_to have_selector(".field_with_errors")
    end
  end

  context "when published is false" do
    let(:event) { create(:event, published: false) }

    it "renders unchecked checkbox" do
      render
      expect(rendered).to have_selector("input[name='event[published]']")
      expect(rendered).not_to have_selector("input[name='event[published]'][checked]")
    end
  end

  context "when published is true" do
    let(:event) { create(:event, :published) }

    it "renders checked checkbox" do
      render
      expect(rendered).to have_selector("input[name='event[published]'][checked]")
    end
  end
end
