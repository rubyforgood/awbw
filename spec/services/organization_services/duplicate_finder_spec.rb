# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationServices::DuplicateFinder do
  def org(attrs = {})
    create(:organization, attrs)
  end

  describe "#groups" do
    it "groups organizations with the same normalized name" do
      a = org(name: "Hope Center")
      b = org(name: "Hope-Center")
      org(name: "Unrelated")

      groups = described_class.new.groups

      expect(groups.size).to eq(1)
      expect(groups.first.records).to contain_exactly(a, b)
      expect(groups.first.reasons).to include("Same name")
    end

    it "groups names that match once a legal suffix is removed" do
      a = org(name: "Bright Futures Inc")
      b = org(name: "Bright Futures LLC")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include("Same name aside from Inc/LLC/etc.")
    end

    it "groups names that differ only by a trailing audience word" do
      a = org(name: "Bright Futures Children's")
      b = org(name: "Bright Futures Adult")
      c = org(name: "Bright Futures Combined")
      org(name: "Bright Futures Adult Programs") # trailing word isn't an audience word

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b, c)
      expect(group.reasons).to include("Same name aside from audience (women's/children's/adult/etc.)")
    end

    it "treats a trailing Women's or Men's as an audience word, but not a bare Women" do
      a = org(name: "Harbor House Women's")
      b = org(name: "Harbor House Men's")
      c = org(name: "Harbor House")
      org(name: "Harbor House Women") # a real name ending, not a version

      expect(described_class.new.groups.first.records).to contain_exactly(a, b, c)
    end

    it "groups names that differ only by a trailing FileMaker code" do
      a = org(name: "Hope Center")
      b = org(name: "Hope Center (ORG00001)")
      c = org(name: "Hope Center (P1234)")
      org(name: "Hope Center 2024") # a number that isn't a FileMaker code

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b, c)
      expect(group.reasons).to include("Same name aside from a FileMaker code in the name")
    end

    it "groups names with a FileMaker code stacked on an audience word or legal suffix" do
      a = org(name: "Bright Futures Inc")
      b = org(name: "Bright Futures Women's (ORG00002)")
      c = org(name: "Bright Futures Combined ORG00003")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b, c)
      expect(group.reasons).to include("Same name aside from audience (women's/children's/adult/etc.)")
    end

    it "ignores the audience word regardless of apostrophe or plural form" do
      a = org(name: "Harbor House Adults")
      b = org(name: "Harbor House Adult's")
      c = org(name: "Harbor House Childrens")

      expect(described_class.new.groups.first.records).to contain_exactly(a, b, c)
    end

    it "flags a FileMaker code present on only one record" do
      org(name: "Sunrise", filemaker_code: "FM123")
      org(name: "Sunrise!", filemaker_code: nil)

      expect(described_class.new.groups.first.reasons).to include("FileMaker code on only one record")
    end

    it "surfaces multiple FileMaker codes as a keep-all conflict" do
      org(name: "Rivertown", filemaker_code: "FM1")
      org(name: "Rivertown!", filemaker_code: "FM2")

      expect(described_class.new.groups.first.reasons)
        .to include(a_string_matching(/Multiple FileMaker codes.*merging keeps all/))
    end

    it "groups records that share one code in a comma-separated list" do
      a = org(name: "Lakeside A", filemaker_code: "FM1, FM2")
      b = org(name: "Lakeside B", filemaker_code: " FM2 ")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include(a_string_matching(/Multiple FileMaker codes \(FM1, FM2\)/))
    end

    it "groups organizations that share an address" do
      a = org(name: "Alpha")
      b = org(name: "Beta")
      create(:address, addressable: a, street_address: "1 Main St", city: "Townsville", zip_code: "10001")
      create(:address, addressable: b, street_address: "1 Main St", city: "Townsville", zip_code: "10001")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include("Shared address")
    end

    it "returns nothing when there are no duplicates" do
      org(name: "Only One")

      expect(described_class.new.groups).to be_empty
    end
  end
end
