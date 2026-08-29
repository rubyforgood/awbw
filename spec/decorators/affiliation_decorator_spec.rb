require "rails_helper"

RSpec.describe AffiliationDecorator do
  describe "#status_badge" do
    it "labels an active affiliation Active" do
      affiliation = build(:affiliation, inactive: false, start_date: 1.year.ago, end_date: nil).decorate
      expect(affiliation.status_badge).to include("Active")
    end

    it "labels an ended affiliation Inactive" do
      affiliation = build(:affiliation, inactive: true, start_date: 3.years.ago, end_date: 1.year.ago).decorate
      expect(affiliation.status_badge).to include("Inactive")
    end
  end

  describe "#period_label" do
    it "renders a closed date range" do
      affiliation = build(:affiliation, start_date: Date.new(2018, 1, 1), end_date: Date.new(2020, 6, 1)).decorate
      expect(affiliation.period_label).to eq("Jan 2018 – Jun 2020")
    end

    it "renders an ongoing affiliation as 'Since'" do
      affiliation = build(:affiliation, start_date: Date.new(2018, 1, 1), end_date: nil).decorate
      expect(affiliation.period_label).to eq("Since Jan 2018")
    end

    it "renders a future affiliation as 'Starts'" do
      affiliation = build(:affiliation, start_date: 2.months.from_now.to_date, end_date: nil).decorate
      expect(affiliation.period_label).to start_with("Starts")
    end

    it "handles missing dates" do
      affiliation = build(:affiliation, start_date: nil, end_date: nil).decorate
      expect(affiliation.period_label).to eq("Dates not recorded")
    end
  end

  # An inactive row sits on the Inactive tab, so a back link must land on the
  # section rather than a row the page isn't showing.
  describe "#return_anchor" do
    it "points at the row itself when the affiliation is active" do
      affiliation = create(:affiliation, start_date: 1.year.ago.to_date, end_date: nil)

      expect(affiliation.decorate.return_anchor).to eq("affiliation_#{affiliation.id}")
    end

    it "points at the affiliations section when the row has ended" do
      affiliation = create(:affiliation, start_date: 2.years.ago.to_date, end_date: 1.year.ago.to_date)

      expect(affiliation.decorate.return_anchor).to eq("affiliations")
    end

    it "points at the section when the flag ended it, not the dates" do
      affiliation = create(:affiliation, start_date: 1.year.ago.to_date, end_date: nil)
      affiliation.inactive_supplied = true
      affiliation.update!(inactive: true)

      expect(affiliation.decorate.return_anchor).to eq("affiliations")
    end
  end
end
