require "rails_helper"

RSpec.describe FeatureDecorator do
  subject(:decorated) { feature.decorate }

  let(:feature) do
    build(:feature, :with_pro_tips,
          name: "Roster slider",
          area: "registration",
          display_status: "admin_facing",
          summary: "Mark certificates from the roster.",
          released_on: Date.new(2026, 8, 9))
  end

  it "labels the area and audience, drawing colour/icon from the shared domain maps" do
    expect(decorated.area_label).to eq("Registration & tickets")
    expect(decorated.status_label).to eq("Admin-facing")
    expect(decorated.area_color).to eq("teal") # DomainTheme.color_for(:event_registrations)
    expect(decorated.area_icon).to eq("fa-ticket") # INDEX_BUTTON_ICONS[:event_registrations]
  end

  describe "#resolved_action_url" do
    it "returns a non-record path unchanged" do
      expect(build(:feature, action_path: "/events/reports").decorate.resolved_action_url).to eq("/events/reports")
      expect(build(:feature, action_path: "/people").decorate.resolved_action_url).to eq("/people")
    end

    it "keeps the deep link when the sample record (id 1) exists" do
      allow(Event).to receive(:exists?).with(1).and_return(true)
      expect(build(:feature, action_path: "/events/1/registrants").decorate.resolved_action_url)
        .to eq("/events/1/registrants")
    end

    it "falls back to the resource index when id 1 is missing" do
      allow(Event).to receive(:exists?).with(1).and_return(false)
      expect(build(:feature, action_path: "/events/1/registrants").decorate.resolved_action_url)
        .to eq("/events")
    end

    it "leaves a blank action_path nil" do
      expect(build(:feature, action_path: nil).decorate.resolved_action_url).to be_nil
    end
  end

  describe "#resolved_action_url with the ticket sentinel" do
    subject(:url) { build(:feature, action_path: FeatureDecorator::TICKET_PATH).decorate.resolved_action_url }

    it "links to a real registrant's ticket when one exists" do
      registration = double(slug: "abc123")
      allow(EventRegistration).to receive(:where).and_return(double(not: double(first: registration)))
      expect(url).to eq("/registration/abc123")
    end

    it "falls back to a sample ticket when there are no registrations" do
      allow(EventRegistration).to receive(:where).and_return(double(not: double(first: nil)))
      allow(Event).to receive(:first).and_return(double(to_param: "5"))
      expect(url).to eq("/events/5/sample_ticket")
    end

    it "falls back to the events index when there are no events" do
      allow(EventRegistration).to receive(:where).and_return(double(not: double(first: nil)))
      allow(Event).to receive(:first).and_return(nil)
      expect(url).to eq("/events")
    end
  end

  describe "#pr_url" do
    it "builds a GitHub PR link when a pr_number is set" do
      expect(build(:feature, pr_number: 2170).decorate.pr_url)
        .to eq("https://github.com/rubyforgood/awbw/pull/2170")
    end

    it "is nil without a pr_number" do
      expect(build(:feature, pr_number: nil).decorate.pr_url).to be_nil
    end
  end

  it "formats the release date" do
    expect(decorated.released_label).to eq("Aug 9, 2026")
  end

  it "falls back to a neutral area for an unknown key" do
    unknown = build(:feature).decorate
    allow(unknown).to receive(:area).and_return("mystery")
    expect(unknown.area_label).to eq("More")
  end

  describe "badges" do
    it "renders the area badge with its icon and label" do
      html = decorated.area_badge
      expect(html).to include("fa-ticket")
      expect(html).to include("Registration &amp; tickets")
    end

    it "renders the audience badge with its icon and label" do
      html = decorated.status_badge
      expect(html).to include("fa-lock")
      expect(html).to include("Admin-facing")
    end
  end
end
