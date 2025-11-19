require 'rails_helper'

RSpec.describe "events/_form", type: :view do
  let(:event) { create(:event, title: "Original Title") }

  before do
    assign(:event, event)
    allow(view).to receive(:current_user).and_return(build_stubbed(:user, super_user: true))
  end

  it "renders all form fields" do
    render

    expect(rendered).to have_selector("form")
    expect(rendered).to have_field("event[title]", with: "Original Title")
    expect(rendered).to have_selector("textarea[name='event[description]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[start_date]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[end_date]']")
    expect(rendered).to have_selector("input[type='datetime-local'][name='event[registration_close_date]']")
    expect(rendered).to have_selector("input[type='checkbox'][name='event[publicly_visible]']")
  end

  it "renders all form labels" do
    render

    expect(rendered).to have_selector("label", text: "Event title")
    expect(rendered).to have_selector("label", text: "Description")
    expect(rendered).to have_selector("label", text: "Start time")
    expect(rendered).to have_selector("label", text: "End time")
    expect(rendered).to have_selector("label", text: "Registration close time")
    expect(rendered).to have_selector("label", text: "Publicly visible")
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
             publicly_visible: true)
    end

    it "populates form fields with existing data" do
      render

      expect(rendered).to have_field("event[title]", with: "Existing Event")
      expect(rendered).to have_selector("textarea", text: "Existing description")
      expect(rendered).to have_selector("input[type='checkbox'][checked='checked']")
    end

    it "populates datetime fields with properly formatted values" do
      render

      expect(rendered).to have_selector("input[type='datetime-local'][value='2024-01-15T10:00']")
      expect(rendered).to have_selector("input[type='datetime-local'][value='2024-01-15T16:00']")
      expect(rendered).to have_selector("input[type='datetime-local'][value='2024-01-10T23:59']")
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

      expect(rendered).to have_content("Title can't be blank")
      expect(rendered).to have_content("Start date can't be blank")
      expect(rendered).to have_content("End date can't be blank")
    end
  end

  context "when event has no errors" do
    it "does not render error messages" do
      render

      expect(rendered).not_to have_selector(".error")
      expect(rendered).not_to have_selector(".field_with_errors")
    end
  end

  context "when publicly_visible is false" do
    let(:event) { create(:event, publicly_visible: false) }

    it "renders unchecked checkbox" do
      render

      expect(rendered).to have_selector("input[type='checkbox'][name='event[publicly_visible]']")
      expect(rendered).not_to have_selector("input[type='checkbox'][checked='checked']")
    end
  end

  context "when publicly_visible is true" do
    let(:event) { create(:event, publicly_visible: true) }

    it "renders checked checkbox" do
      render

      expect(rendered).to have_selector("input[type='checkbox'][name='event[publicly_visible]'][checked='checked']")
    end
  end
end
