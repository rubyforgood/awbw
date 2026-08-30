# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::DuplicateFinder do
  def person(attrs = {})
    create(:person, { user: nil }.merge(attrs))
  end

  describe "#groups" do
    it "groups people with the same normalized name" do
      a = person(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
      b = person(first_name: "Jane", last_name: "Doe", email: "jane.doe@work.com")
      person(first_name: "Unrelated", last_name: "Person")

      groups = described_class.new.groups

      expect(groups.size).to eq(1)
      expect(groups.first.records).to contain_exactly(a, b)
      expect(groups.first.reasons).to include("Same name")
    end

    it "groups people whose first name is a nickname or legal-name variant of the other" do
      a = person(first_name: "Bob", last_name: "Smith", email: "bob@example.com")
      b = person(first_name: "Robert", last_name: "Smith", email: "robert@example.com")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include("Same name (nickname or legal-name variant)")
    end

    it "matches on the legal first name too" do
      a = person(first_name: "Rob", legal_first_name: "Robert", last_name: "Jones", email: "a@example.com")
      b = person(first_name: "Bobby", last_name: "Jones", email: "b@example.com")

      expect(described_class.new.groups.first.records).to contain_exactly(a, b)
    end

    it "groups people who share an email address" do
      a = person(first_name: "Chris", last_name: "Alpha", email: "shared@example.com")
      b = person(first_name: "Kris", last_name: "Beta", email: "SHARED@example.com")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include("Shared email")
    end

    it "matches an email stored in the secondary email_2 field" do
      a = person(first_name: "Dana", last_name: "Gamma", email: "dana@primary.com")
      b = person(first_name: "Dana", last_name: "Delta", email: "dana@other.com", email_2: "dana@primary.com")

      expect(described_class.new.groups.first.records).to contain_exactly(a, b)
    end

    it "groups people with the same FileMaker code" do
      a = person(first_name: "Erin", last_name: "One", email: "e1@example.com", filemaker_code: "FM777")
      b = person(first_name: "Erin", last_name: "Two", email: "e2@example.com", filemaker_code: "FM777")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include("Same FileMaker code (FM777)")
    end

    it "flags different FileMaker codes on records grouped by another signal as a caution" do
      person(first_name: "Fay", last_name: "Nguyen", email: "fay@example.com", filemaker_code: "FM1")
      person(first_name: "Fay", last_name: "Nguyen", email: "fay2@example.com", filemaker_code: "FM2")

      expect(described_class.new.groups.first.reasons)
        .to include(a_string_matching(/Different FileMaker codes \(FM1, FM2\)/))
    end

    it "groups people with the same date of birth and last name" do
      dob = Date.new(1990, 5, 1)
      a = person(first_name: "Gene", last_name: "Rivers", email: "g1@example.com", date_of_birth: dob)
      b = person(first_name: "Eugene", last_name: "Rivers", email: "g2@example.com", date_of_birth: dob)

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include("Same date of birth")
    end

    it "returns nothing when there are no duplicates" do
      person(first_name: "Only", last_name: "One", email: "only@example.com")

      expect(described_class.new.groups).to be_empty
    end
  end
end
