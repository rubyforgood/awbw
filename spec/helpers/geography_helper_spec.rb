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

  describe "#country_select_options" do
    it "returns the country list when the value is blank or a known country" do
      expect(helper.country_select_options).to eq(CountryName.options)
      expect(helper.country_select_options("USA")).to eq(CountryName.options)
    end

    it "appends an unrecognized value so it stays selectable" do
      expect(helper.country_select_options("Narnia").last).to eq("Narnia")
    end
  end
end
