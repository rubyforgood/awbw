# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationServices::FilemakerNames do
  before do
    FmOrganization.create!(fm_id: "ORG00001", data: { "OrgName" => "Harbor House" })
    FmProject.create!(fm_id: "P0001", data: { "OrgID" => "ORG00001", "ProjectName" => "Harbor Art" })
    FmOrganization.create!(fm_id: "ORG00002", data: { "OrgName" => "Valley Services" })
    FmOrganization.create!(fm_id: "ORG00003", data: { "OrgName" => "Harbor Women’s Center" })
  end

  def answers?(name, code)
    described_class.new.answers?(build(:organization, name:, filemaker_code: code))
  end

  describe "#answers?" do
    it "accepts a name differing only in case, punctuation, a legal suffix or the namesake's code" do
      expect(answers?("harbor house, inc.", "ORG00001")).to be(true)
      expect(answers?("Harbor House (ORG00001)", "ORG00001")).to be(true)
    end

    it "reads a mis-encoded apostrophe as one" do
      expect(answers?("Harbor Womenís Center", "ORG00003")).to be(true)
    end

    it "accepts the old app's trailing audience word" do
      expect(answers?("Harbor Art Women's", "P0001")).to be(true)
      expect(answers?("Harbor Art Combined", "P0001")).to be(true)
    end

    it "accepts a name holding every telling word of the other, or held within it" do
      expect(answers?("Harbor House - Outreach Children's", "ORG00001")).to be(true)
      expect(answers?("The Valley Services Shelter", "ORG00002")).to be(true)
      expect(answers?("Valley", "ORG00002")).to be(false)
    end

    it "lets a project go by its organization's name, and an organization by its project's" do
      expect(answers?("Harbor House", "P0001")).to be(true)
      expect(answers?("Harbor Art", "ORG00001")).to be(true)
    end

    it "accepts any of the names a merged organization's codes go by" do
      expect(answers?("Valley Services", "ORG00001, ORG00002")).to be(true)
    end

    it "accepts any name on a code staff confirmed is the same place" do
      stub_const("FilemakerValues::SAME_PLACE_CODES", %w[ORG00001])

      expect(answers?("Sunrise Clinic", "ORG00001")).to be(true)
    end

    it "rejects a name none of its codes go by" do
      expect(answers?("Sunrise Clinic", "ORG00001")).to be(false)
      expect(answers?("Sunrise Clinic", "7")).to be(false)
    end
  end

  describe "#pick" do
    it "prefers the organization answering to its codes, else the first" do
      stray = create(:organization, name: "Sunrise Clinic", filemaker_code: "ORG00001")
      harbor = create(:organization, name: "Harbor House", filemaker_code: "ORG00001")
      names = described_class.new

      expect(names.pick([ stray, harbor ])).to eq(harbor)
      expect(names.pick([ stray ])).to eq(stray)
    end
  end
end
