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

  describe "#form_role_options" do
    it "separates the role groups with a rule and marks the selected role" do
      html = helper.form_role_options("scholarship")
      expect(html.scan("<hr>").size).to eq(Form::ROLE_GROUPS.size - 1)
      expect(html).to include('<option selected="selected" value="scholarship">Scholarship application</option>')
    end

    it "drops excluded roles and any group they empty" do
      html = helper.form_role_options("general", except: Form::SURVEY_ROLES)
      expect(html).not_to include("survey")
      expect(html.scan("<hr>").size).to eq(2)
    end
  end
end
