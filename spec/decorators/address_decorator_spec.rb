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

  describe "person type choices" do
    it "offers personal or mailing, starting a new address as personal" do
      address = build(:address, address_type: nil).decorate

      expect(address.person_type_options).to eq([ [ "Personal", "personal" ], [ "Mailing", "mailing" ] ])
      expect(address.person_type_selected).to eq("personal")
    end

    it "keeps the type an address already holds as a choice, so saving doesn't change it" do
      address = build(:address, address_type: "work").decorate

      expect(address.person_type_options.map(&:last)).to eq(%w[personal mailing work])
      expect(address.person_type_selected).to eq("work")
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

  describe "defaults for a new address" do
    let(:person) { create(:person) }

    def new_address
      person.addresses.reload.build.decorate
    end

    it "keeps a saved address's own values" do
      address = create(:address, addressable: person, state: "CA", country: "Canada", locality: "Outside USA").decorate

      expect(address.default_country).to eq("Canada")
      expect(address.default_state).to eq("CA")
      expect(address.state_as_text?).to be(true)
    end

    it "copies the saved address's country, state, and locality" do
      create(:address, addressable: person, state: "CA", country: "United States", locality: "LA County")

      expect(new_address.default_country).to eq("United States")
      expect(new_address.default_state).to eq("CA")
      expect(new_address.default_locality).to eq("LA County")
      expect(new_address.state_as_text?).to be(false)
    end

    it "prefers the most recently updated saved address" do
      create(:address, addressable: person, state: "AB", country: "Canada", updated_at: 2.days.ago)
      create(:address, addressable: person, state: "NY", country: "United States", updated_at: 1.hour.ago)

      expect(new_address.default_country).to eq("United States")
      expect(new_address.default_state).to eq("NY")
      expect(new_address.state_as_text?).to be(false)
    end

    it "takes an active saved address over a more recently updated inactive one" do
      create(:address, addressable: person, state: "AB", country: "Canada", updated_at: 2.days.ago)
      create(:address, addressable: person, state: "NY", country: "United States", inactive: true, updated_at: 1.hour.ago)

      expect(new_address.default_country).to eq("Canada")
      expect(new_address.default_state).to eq("AB")
      expect(new_address.state_as_text?).to be(true)
    end

    it "falls back to the Settings default country when nothing is saved" do
      allow(Setting).to receive(:default_address_country).and_return("Canada")

      expect(new_address.default_country).to eq("Canada")
      expect(new_address.default_state).to be_nil
      expect(new_address.state_as_text?).to be(true)
    end
  end

  describe "#default_locality" do
    it "keeps a locality that's set" do
      expect(build(:address, locality: "LA City", country: "Canada").decorate.default_locality).to eq("LA City")
    end

    it "fills a blank locality with Outside USA for a non-USA address" do
      expect(build(:address, locality: nil, state: "AB", country: "Canada").decorate.default_locality).to eq("Outside USA")
    end

    it "fills a blank locality with Outside CA for a US state other than California" do
      expect(build(:address, locality: nil, state: "NY", country: "United States").decorate.default_locality).to eq("Outside CA")
    end

    it "fills a blank locality with the California county's region" do
      address = build(:address, locality: nil, state: "CA", country: "United States", city: "Fresno", county: "Fresno")

      expect(address.decorate.default_locality).to eq("Central CA")
    end

    it "leaves a blank locality blank in a California county with no region" do
      address = build(:address, locality: nil, state: "CA", country: "United States", city: "Markleeville", county: "Alpine")

      expect(address.decorate.default_locality).to be_nil
    end

    it "fills a blank locality with LA City for a Los Angeles address" do
      address = build(:address, locality: nil, state: "CA", country: "United States", city: "Los Angeles", county: "Los Angeles")

      expect(address.decorate.default_locality).to eq("LA City")
    end

    it "leaves a blank locality blank for a state no US state answers to" do
      address = build(:address, locality: nil, state: "ON", country: nil)

      expect(address.decorate.default_locality).to be_nil
    end

    it "derives a new address's locality when the saved one has none" do
      person = create(:person)
      create(:address, addressable: person, state: "NY", country: "United States").update_column(:locality, nil)

      expect(person.addresses.reload.build.decorate.default_locality).to eq("Outside CA")
    end
  end
end
