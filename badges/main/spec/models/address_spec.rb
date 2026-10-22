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

  describe "#display_lines" do
    it "renders the street line and a combined city, state zip line" do
      address = build(:address, street_address: "123 Main St", city: "Springfield",
                                state: "IL", zip_code: "62704")

      expect(address.display_lines).to eq([ "123 Main St", "Springfield, IL 62704" ])
    end

    it "omits a blank street line rather than leaving a gap" do
      address = build(:address, street_address: "", city: "Springfield",
                                state: "IL", zip_code: "62704")

      expect(address.display_lines).to eq([ "Springfield, IL 62704" ])
    end
  end

  describe ".display_lines_for" do
    let(:organization) { create(:organization) }

    it "returns nothing for an owner that has no addresses at all" do
      expect(Address.display_lines_for(organization)).to eq([])
    end

    it "returns nothing for an owner that can't have addresses" do
      expect(Address.display_lines_for(nil)).to eq([])
    end

    it "prefers the address flagged for invoices over the first one" do
      create(:address, addressable: organization, street_address: "1 First Ave", city: "Springfield", state: "IL", zip_code: "62704")
      create(:address, addressable: organization, street_address: "2 Billing Rd", city: "Shelbyville", state: "IL", zip_code: "62565",
                       invoice_address: true)

      expect(Address.display_lines_for(organization)).to eq([ "2 Billing Rd", "Shelbyville, IL 62565" ])
    end

    it "prints the oldest flagged address when an owner has marked several" do
      first = create(:address, addressable: organization, street_address: "1 First Billing Rd", city: "Springfield",
                               state: "IL", zip_code: "62704", invoice_address: true)
      create(:address, addressable: organization, street_address: "2 Later Billing Rd", city: "Shelbyville",
                       state: "IL", zip_code: "62565", invoice_address: true)

      expect(Address.display_lines_for(organization)).to eq(first.display_lines)
    end

    it "falls back to the first active address when none is flagged" do
      create(:address, addressable: organization, street_address: "1 First Ave", city: "Springfield", state: "IL", zip_code: "62704")

      expect(Address.display_lines_for(organization)).to eq([ "1 First Ave", "Springfield, IL 62704" ])
    end

    it "skips inactive addresses" do
      create(:address, addressable: organization, street_address: "1 Old Ave", city: "Springfield", state: "IL", zip_code: "62704",
                       inactive: true)

      expect(Address.display_lines_for(organization)).to eq([])
    end
  end

  describe "the invoice flag" do
    let(:organization) { create(:organization) }

    it "lets an owner mark as many of its addresses as it likes" do
      first = create(:address, addressable: organization, invoice_address: true)
      second = create(:address, addressable: organization, invoice_address: true)

      expect(organization.addresses.for_invoices).to contain_exactly(first, second)
    end

    it "leaves an unmarked address out, however it stores the flag" do
      create(:address, addressable: organization, invoice_address: false)
      create(:address, addressable: organization)

      expect(organization.addresses.for_invoices).to be_empty
    end
  end
end
