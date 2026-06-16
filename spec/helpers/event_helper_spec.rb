require "rails_helper"

RSpec.describe EventHelper, type: :helper do
  describe "#specify_placeholder" do
    it "returns the placeholder for 'Other' case- and whitespace-insensitively" do
      expect(helper.specify_placeholder("Other")).to eq("Please specify")
      expect(helper.specify_placeholder("  other  ")).to eq("Please specify")
    end

    it "returns the option-specific placeholder for named sources" do
      expect(helper.specify_placeholder("Word of Mouth")).to eq("Please list the name of the person")
      expect(helper.specify_placeholder("Foundation/Funder")).to eq("Please list the name of the foundation/funder")
      expect(helper.specify_placeholder("Work(ed) at an agency that has/had an AWBW program"))
        .to eq("Please specify organization")
    end

    it "returns nil for options that do not reveal a box" do
      expect(helper.specify_placeholder("Yes")).to be_nil
      expect(helper.specify_placeholder("Other reasons")).to be_nil
      expect(helper.specify_placeholder(nil)).to be_nil
    end
  end

  describe "#specify_option_selected?" do
    it "is true for a bare label answer" do
      expect(helper.specify_option_selected?("Other", "Other")).to be true
      expect(helper.specify_option_selected?("Word of Mouth", "Word of Mouth")).to be true
    end

    it "is true for a '<label>: <text>' answer" do
      expect(helper.specify_option_selected?("Other", "Other: purple")).to be true
      expect(helper.specify_option_selected?("Word of Mouth", "Word of Mouth: Jane")).to be true
    end

    it "is true when an array of answers includes the option" do
      expect(helper.specify_option_selected?("Other", [ "Red", "Other: teal" ])).to be true
    end

    it "is false when no answer represents the given option" do
      expect(helper.specify_option_selected?("Other", "Yes")).to be false
      expect(helper.specify_option_selected?("Other", [ "Red", "Blue" ])).to be false
      expect(helper.specify_option_selected?("Word of Mouth", "Other: teal")).to be false
      expect(helper.specify_option_selected?("Other", nil)).to be false
    end
  end

  describe "#resolve_answer_text" do
    it "maps category ids to names while preserving an 'Other: <text>' token" do
      category_type = create(:category_type, name: "StoryPopulation")
      veterans = create(:category, :published, category_type: category_type, name: "Veterans")
      field = build_stubbed(:form_field, field_identifier: "client_life_experiences")

      result = helper.resolve_answer_text(field, "#{veterans.id}, Other: refugees")

      expect(result).to eq("Veterans, Other: refugees")
    end
  end

  describe "#specify_option_text" do
    it "extracts the custom text from a '<label>: <text>' answer" do
      expect(helper.specify_option_text("Other", "Other: bright purple")).to eq("bright purple")
      expect(helper.specify_option_text("Word of Mouth", "Word of Mouth: Jane Doe")).to eq("Jane Doe")
    end

    it "extracts the custom text from a multi-select answer array" do
      expect(helper.specify_option_text("Other", [ "Red", "Other: teal" ])).to eq("teal")
    end

    it "returns an empty string for a bare label answer" do
      expect(helper.specify_option_text("Other", "Other")).to eq("")
    end

    it "returns an empty string when there is no answer for the option" do
      expect(helper.specify_option_text("Other", "Yes")).to eq("")
      expect(helper.specify_option_text("Word of Mouth", "Other: teal")).to eq("")
      expect(helper.specify_option_text("Other", nil)).to eq("")
    end
  end
end
