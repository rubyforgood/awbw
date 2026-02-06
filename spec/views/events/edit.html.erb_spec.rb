require 'rails_helper'

RSpec.describe "events/edit", type: :view do
  let(:event) do
    create(:event,
           title: "Original Title",
           description: "Original description",
           start_date: DateTime.new(2024, 1, 15, 10, 0),
           end_date: DateTime.new(2024, 1, 15, 16, 0),
           registration_close_date: DateTime.new(2024, 1, 10, 23, 59),
           published: true)
  end

  before do
    assign(:event, event)
    allow(view).to receive(:current_user).and_return(build_stubbed(:user, :admin))
    allow(view).to receive(:allowed_to?).with(:manage?, event).and_return(true)
    allow(view).to receive(:allowed_to?).with(:destroy?, event).and_return(true)
  end

  it "renders the editing event heading" do
    render

    expect(rendered).to have_selector("h1", text: "Edit Event")
  end

  it "renders the form partial with event data" do
    render

    expect(rendered).to have_selector("form")
    expect(rendered).to have_field("event[title]", with: "Original Title")
    expect(rendered).to have_selector(
                          "textarea[name='event[description]']",
                          text: "Original description"
                        )

    # published is true → checked
    expect(rendered).to have_checked_field("event[published]")
  end

  it "renders action links" do
    render

    expect(rendered).to have_link("View", href: event_path(event))
  end

  it "renders submit button" do
    render

    expect(rendered).to have_selector("input[type='submit']")
  end

  context "when event has errors" do
    let(:event) do
      event = create(:event, title: "Test Event")
      event.errors.add(:title, "can't be blank")
      event.errors.add(:start_date, "can't be blank")
      event
    end

    it "renders the form with errors" do
      render

      expect(rendered).to have_selector("form")
    end
  end

  context "when event is unpublished" do
    let(:event) do
      create(:event,
             title: "Private Event",
             published: false)
    end

    it "renders unpublished state correctly" do
      render

      expect(rendered).to have_unchecked_field("event[published]")
    end
  end
end
