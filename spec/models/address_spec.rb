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

  describe "address type" do
    it "records an untyped address as unknown on save" do
      address = create(:address, address_type: nil)

      expect(address.address_type).to eq("unknown")
      expect(address).not_to be_known_type
    end

    it "leaves a type it was given alone" do
      expect(create(:address, address_type: "mailing")).to have_attributes(address_type: "mailing", known_type?: true)
    end

    it "types a legacy blank row on its next save, not before" do
      address = create(:address)
      address.update_columns(address_type: nil)

      expect(address.reload.address_type).to be_nil

      address.update!(city: "Missoula")

      expect(address.address_type).to eq("unknown")
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
end
