require "rails_helper"

RSpec.describe Address, type: :model do
  describe "associations" do
    it { should belong_to(:addressable) }
  end

  describe "validations" do
    let(:address) { build(:address) }

    it "is valid with valid attributes" do
      expect(address).to be_valid
    end

    it "requires a locality" do
      address.locality = nil
      expect(address).not_to be_valid
      expect(address.errors[:locality]).to include("can't be blank")
    end

    it "requires a city" do
      address.city = nil
      expect(address).not_to be_valid
      expect(address.errors[:city]).to include("can't be blank")
    end

    it "requires a state" do
      address.state = nil
      expect(address).not_to be_valid
      expect(address.errors[:state]).to include("can't be blank")
    end

    it "requires an addressable" do
      address.addressable = nil
      expect(address).not_to be_valid
      expect(address.errors[:addressable]).to include("must exist")
    end
  end

  describe "optional fields" do
    let(:address) { build(:address) }

    it "allows street_address to be nil" do
      address.street_address = nil
      expect(address).to be_valid
    end
    it "allows zip_code to be nil" do
      address.zip_code = nil
      expect(address).to be_valid
    end

    it "allows country to be nil" do
      address.country = nil
      expect(address).to be_valid
    end

    it "allows county to be nil" do
      address.county = nil
      expect(address).to be_valid
    end

    it "allows LA-specific fields to be nil" do
      address.la_city_council_district = nil
      address.la_supervisorial_district = nil
      address.la_service_planning_area = nil
      expect(address).to be_valid
    end
  end

  describe "state by country" do
    it "treats a blank or United States country as domestic" do
      expect(build(:address, country: nil)).to be_united_states
      expect(build(:address, country: "United States")).to be_united_states
      expect(build(:address, country: "Canada")).not_to be_united_states
    end

    it "accepts a recognized US state abbreviation for a domestic address" do
      address = build(:address, country: "United States", state: "CA")
      expect(address).to be_valid
    end

    it "rejects an unrecognized state for a domestic address" do
      address = build(:address, country: "United States", state: "Ontario")
      expect(address).not_to be_valid
      expect(address.errors[:state]).to include("is not a valid US state")
    end

    it "accepts a free-form region for an international address" do
      address = build(:address, country: "Canada", state: "Ontario")
      expect(address).to be_valid
    end

    it "still requires a state for an international address" do
      address = build(:address, country: "Canada", state: nil)
      expect(address).not_to be_valid
      expect(address.errors[:state]).to include("can't be blank")
    end
  end

  describe "#name" do
    it "formats a US address with a state" do
      address = build(:address, street_address: "123 Main St", city: "Los Angeles",
                                state: "CA", zip_code: "90001")
      expect(address.name).to eq("123 Main St, Los Angeles, CA 90001")
    end

    it "omits a blank state without leaving a stray separator" do
      address = build(:address, street_address: "10 King St W", city: "Toronto",
                                state: nil, zip_code: "M5H 1B6")
      expect(address.name).to eq("10 King St W, Toronto, M5H 1B6")
    end
  end
end
