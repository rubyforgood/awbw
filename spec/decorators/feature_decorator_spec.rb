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

  it "labels the area and audience" do
    expect(decorated.area_label).to eq("Registration & tickets")
    expect(decorated.status_label).to eq("Admin-facing")
    expect(decorated.area_color).to eq("amber")
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

  describe "#pr_url" do
    it "builds a GitHub PR link when a pr_number is set" do
      expect(build(:feature, pr_number: 2170).decorate.pr_url)
        .to eq("https://github.com/rubyforgood/awbw/pull/2170")
    end

    it "is nil without a pr_number" do
      expect(build(:feature, pr_number: nil).decorate.pr_url).to be_nil
    end
  end

  it "formats the release date and an ISO date for the JS filter" do
    expect(decorated.released_label).to eq("Aug 9, 2026")
    expect(decorated.released_iso).to eq("2026-08-09")
  end

  it "builds a lowercased search haystack from name, summary, tips, area, and audience" do
    text = decorated.search_text
    expect(text).to include("roster slider")
    expect(text).to include("mark certificates")
    expect(text).to include("first tip")
    expect(text).to include("registration & tickets")
    expect(text).to include("admin-facing")
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
