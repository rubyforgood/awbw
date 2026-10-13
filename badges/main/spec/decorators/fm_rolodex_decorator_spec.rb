require "rails_helper"

RSpec.describe FmRolodexDecorator do
  describe "#contact_tags" do
    let(:rolodex) { FmRolodex.new(data: { "PrimaryPhoneID" => "100", "PrimaryAddrsID" => "200", "WorksiteAddrsID" => "200" }).decorate }

    it "tags the primary phone" do
      expect(rolodex.contact_tags(FmPhoneNumber.new(fm_id: "100"))).to eq([ "Primary" ])
    end

    it "tags an address that is both primary and worksite" do
      expect(rolodex.contact_tags(FmAddress.new(fm_id: "200"))).to eq(%w[Primary Worksite])
    end

    it "keeps phone and address IDs apart" do
      expect(rolodex.contact_tags(FmPhoneNumber.new(fm_id: "200"))).to be_empty
    end
  end
end
