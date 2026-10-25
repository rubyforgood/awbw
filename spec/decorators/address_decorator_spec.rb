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

  describe "#default_country and #state_as_text?" do
    let(:person) { create(:person) }

    def new_address
      person.addresses.reload.build.decorate
    end

    it "keeps a saved address's own country and state field" do
      address = create(:address, addressable: person, state: "CA", country: "Canada").decorate

      expect(address.default_country).to eq("Canada")
      expect(address.state_as_text?).to be(true)
    end

    it "starts a new address in the saved address's country" do
      create(:address, addressable: person, country: "United States")

      expect(new_address.default_country).to eq("United States")
      expect(new_address.state_as_text?).to be(false)
    end

    it "prefers the primary saved address" do
      create(:address, addressable: person, country: "United States", primary: false)
      create(:address, addressable: person, state: "AB", country: "Canada", primary: true)

      expect(new_address.default_country).to eq("Canada")
      expect(new_address.state_as_text?).to be(true)
    end

    it "starts a new address in the United States when nothing is saved" do
      expect(new_address.default_country).to eq("United States")
      expect(new_address.state_as_text?).to be(false)
    end
  end

  describe "#default_locality" do
    it "keeps a locality that's set" do
      expect(build(:address, locality: "LA City", country: "Canada").decorate.default_locality).to eq("LA City")
    end

    it "fills a blank locality with Outside USA for a non-USA address" do
      expect(build(:address, locality: nil, state: "AB", country: "Canada").decorate.default_locality).to eq("Outside USA")
    end

    it "leaves a blank locality blank for a US address" do
      expect(build(:address, locality: nil, state: "CA", country: "United States").decorate.default_locality).to be_nil
    end
  end
end
