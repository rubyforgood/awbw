require "rails_helper"

RSpec.describe FormsHelper, type: :helper do
  describe "#max_length_placeholder" do
    it "names the input and its limit" do
      expect(helper.max_length_placeholder("Question text", 1000)).to eq("Question text (1,000 char max)")
    end
  end

  describe "#form_role_label" do
    it "uses the role's dropdown label" do
      expect(helper.form_role_label(build(:form, role: "continuing_education"))).to eq("Continuing education application")
    end

    it "falls back to General when no role is set" do
      expect(helper.form_role_label(build(:form, role: nil))).to eq("General")
    end
  end
end
