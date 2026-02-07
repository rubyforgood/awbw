require "rails_helper"

RSpec.describe "events/index", type: :view do
  let(:admin) { create(:user, :admin) }

  let(:event_closed) { create(:event, :published, title: "Closed Event", registration_close_date: 3.days.ago) }
  let(:event_open)   { create(:event, :published, title: "Open Event", registration_close_date: 5.days.from_now) }
  let(:event_open_2) { create(:event, :published, title: "Open Event 2", registration_close_date: nil) }

  before do
    allow(view).to receive(:current_user).and_return(admin)
    allow(view).to receive(:allowed_to?).and_return(true)
  end

  describe "with events present" do
    before do
      assign(:events, [ event_open, event_open_2, event_closed ])
      render
    end

    it "renders event titles" do
      expect(rendered).to include("Open Event")
      expect(rendered).to include("Open Event 2")
      expect(rendered).to include("Closed Event")
    end

    it "renders edit links when allowed" do
      expect(rendered).to have_link("Edit", href: edit_event_path(event_open))
    end

    it "renders New Event link" do
      expect(rendered).to have_link("New Event", href: new_event_path)
    end
  end

  describe "when no events exist" do
    before do
      assign(:events, [])
      render
    end

    it "renders empty message" do
      expect(rendered).to include("No events available")
    end
  end

  describe "when not allowed" do
    before do
      allow(view).to receive(:allowed_to?).and_return(false)
      assign(:events, [ event_open ])
      render
    end

    it "does not render edit link" do
      expect(rendered).not_to have_link("Edit")
    end

    it "does not render New Event link" do
      expect(rendered).not_to have_link("New Event")
    end
  end
end
