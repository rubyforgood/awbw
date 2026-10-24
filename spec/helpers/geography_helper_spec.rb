require "rails_helper"

RSpec.describe GeographyHelper, type: :helper do
  describe "#state_select_options" do
    it "returns the US states unchanged for a known abbreviation" do
      expect(helper.state_select_options("CA")).to eq(helper.us_states)
    end

    it "returns the US states unchanged when no value is given" do
      expect(helper.state_select_options).to eq(helper.us_states)
      expect(helper.state_select_options("")).to eq(helper.us_states)
    end

    it "appends a non-US value so an international state stays selectable" do
      options = helper.state_select_options("ON")

      expect(options).to include([ "ON", "ON" ])
      expect(options.last).to eq([ "ON", "ON" ])
    end

    it "does not duplicate a value that is already a known state" do
      expect(helper.state_select_options("NY").count { |_name, abbr| abbr == "NY" }).to eq(1)
    end
  end

  describe "country options" do
    it "lists the United States first, then every other country A–Z" do
      expect(GeographyHelper::COUNTRIES.first).to eq("United States")
      expect(GeographyHelper::COUNTRIES.drop(1)).to eq(GeographyHelper::COUNTRIES.drop(1).sort)
      expect(GeographyHelper::COUNTRIES.count("United States")).to eq(1)
      expect(GeographyHelper::COUNTRIES).to include("Canada", "Mexico")
      expect(GeographyHelper::COUNTRIES).not_to include("United States Minor Outlying Islands")
    end

    it "offers the everyday name rather than the formal ISO one" do
      expect(GeographyHelper::COUNTRIES)
        .to include("Russia", "Syria", "Laos", "Vatican City", "Palestine", "Democratic Republic of the Congo")
      expect(GeographyHelper::COUNTRIES)
        .not_to include("Russian Federation", "Syrian Arab Republic", "Lao People's Democratic Republic")
    end

    # A form's answers split on ", " when tallied, so a comma here would break one
    # country into two rows on the forms map.
    it "keeps commas out of every option" do
      expect(GeographyHelper::COUNTRIES.grep(/,/)).to be_empty
    end
  end
end
