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
end
