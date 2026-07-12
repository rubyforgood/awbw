require "rails_helper"

RSpec.describe ProfessionalLicense, type: :model do
  let(:person) { create(:person) }

  describe ".find_or_create_for" do
    it "creates and then reuses a license for a given number" do
      first = described_class.find_or_create_for(person: person, number: "ABC-1")
      second = described_class.find_or_create_for(person: person, number: "ABC-1")

      expect(first).to eq(second)
      expect(person.professional_licenses.count).to eq(1)
    end

    it "creates a separate license for a different number" do
      described_class.find_or_create_for(person: person, number: "ABC-1")
      described_class.find_or_create_for(person: person, number: "ABC-2")

      expect(person.professional_licenses.count).to eq(2)
    end

    it "reuses a single placeholder when no number is given" do
      first = described_class.find_or_create_for(person: person, number: "")
      second = described_class.find_or_create_for(person: person, number: nil)

      expect(first).to eq(second)
      expect(first.number).to be_nil
      expect(person.professional_licenses.count).to eq(1)
    end
  end

  describe "#number_known?" do
    it "is true only when a number is present" do
      expect(build(:professional_license, number: "X")).to be_number_known
      expect(build(:professional_license, :placeholder)).not_to be_number_known
    end
  end

  describe "#expired?" do
    it "is true only for a past expiration on file" do
      expect(build(:professional_license, expires_on: Date.current - 1)).to be_expired
      expect(build(:professional_license, expires_on: Date.current + 1)).not_to be_expired
      expect(build(:professional_license, expires_on: nil)).not_to be_expired
    end
  end

  describe "validations" do
    it "rejects a duplicate number for the same person" do
      create(:professional_license, person: person, number: "DUP")
      dup = build(:professional_license, person: person, number: "DUP")

      expect(dup).not_to be_valid
    end
  end
end
