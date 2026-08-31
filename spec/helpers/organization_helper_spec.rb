require "rails_helper"

RSpec.describe OrganizationHelper, type: :helper do
  describe "#organization_profile_button" do
    let(:organization) { create(:organization) }

    it "defaults the profile link to _top so it can't Oopsie a lazy results frame" do
      link = Nokogiri::HTML(helper.organization_profile_button(organization)).at_css("a")
      expect(link["data-turbo-frame"]).to eq("_top")
    end

    it "lets a caller override the frame target" do
      link = Nokogiri::HTML(
        helper.organization_profile_button(organization, data: { turbo_frame: "organizations_results" })
      ).at_css("a")
      expect(link["data-turbo-frame"]).to eq("organizations_results")
    end
  end
end
