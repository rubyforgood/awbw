require "rails_helper"

RSpec.describe OrganizationHelper, type: :helper do
  describe "#organization_profile_button" do
    let(:organization) { create(:organization) }

    it "forwards a caller's data-turbo-frame onto the link so call sites can break out of a frame" do
      link = Nokogiri::HTML(
        helper.organization_profile_button(organization, data: { turbo_frame: "_top" })
      ).at_css("a")
      expect(link["data-turbo-frame"]).to eq("_top")
    end
  end
end
