require "rails_helper"

RSpec.describe AddressDecorator do
  describe "#address_type_label" do
    it "humanizes the address type" do
      expect(build(:address, address_type: "personal").decorate.address_type_label).to eq("Personal")
    end

    it "is nil without an address type" do
      expect(build(:address, address_type: nil).decorate.address_type_label).to be_nil
    end
  end

  describe "#picker_label" do
    let(:organization) { create(:organization) }

    it "labels a plain address with just its name" do
      address = create(:address, addressable: organization, street_address: "1 Plain St")

      expect(address.decorate.picker_label).to eq(address.name)
      expect(address.decorate.picker_label).not_to include("invoice address")
    end

    it "names the one marked for invoices" do
      address = create(:address, addressable: organization, street_address: "9 Billing Rd", invoice_address: true)

      expect(address.decorate.picker_label).to start_with(address.name)
      expect(address.decorate.picker_label).to include("invoice address")
    end
  end
end
