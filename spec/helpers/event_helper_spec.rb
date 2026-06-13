require "rails_helper"

RSpec.describe EventHelper, type: :helper do
  describe "#other_option?" do
    it "matches the 'Other' label case- and whitespace-insensitively" do
      expect(helper.other_option?("Other")).to be true
      expect(helper.other_option?("other")).to be true
      expect(helper.other_option?("  OTHER  ")).to be true
    end

    it "does not match other labels" do
      expect(helper.other_option?("Yes")).to be false
      expect(helper.other_option?("Other reasons")).to be false
      expect(helper.other_option?(nil)).to be false
    end
  end

  describe "#other_option_selected?" do
    it "is true for a bare 'Other' answer" do
      expect(helper.other_option_selected?("Other")).to be true
    end

    it "is true for an 'Other: <text>' answer" do
      expect(helper.other_option_selected?("Other: purple")).to be true
    end

    it "is true when an array of answers includes the Other choice" do
      expect(helper.other_option_selected?([ "Red", "Other: teal" ])).to be true
    end

    it "is false when no answer represents the Other choice" do
      expect(helper.other_option_selected?("Yes")).to be false
      expect(helper.other_option_selected?([ "Red", "Blue" ])).to be false
      expect(helper.other_option_selected?(nil)).to be false
    end
  end

  describe "#other_option_text" do
    it "extracts the custom text from an 'Other: <text>' answer" do
      expect(helper.other_option_text("Other: bright purple")).to eq("bright purple")
    end

    it "extracts the custom text from a multi-select answer array" do
      expect(helper.other_option_text([ "Red", "Other: teal" ])).to eq("teal")
    end

    it "returns an empty string for a bare 'Other' answer" do
      expect(helper.other_option_text("Other")).to eq("")
    end

    it "returns an empty string when there is no Other answer" do
      expect(helper.other_option_text("Yes")).to eq("")
      expect(helper.other_option_text(nil)).to eq("")
    end
  end
end
