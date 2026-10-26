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

  describe "text field line breaks" do
    it "drops blank lines and surrounding whitespace, keeping one break between real lines" do
      address = build(:address, street_address: "  12 Main St \r\n\r\n\n Suite 4 \n", city: "Los Angeles\n\n", county: "\n")

      expect(address.street_address).to eq("12 Main St\nSuite 4")
      expect(address.city).to eq("Los Angeles")
      expect(address.county).to eq("")
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

    it "marks a mailing address for invoices" do
      address = create(:address, addressable: create(:person), address_type: "mailing")

      expect(address).to be_invoice_address
    end

    it "unmarks an address that stops being mailing" do
      address = create(:address, addressable: create(:person), address_type: "mailing")

      address.update!(address_type: "personal")

      expect(address).not_to be_invoice_address
    end

    it "leaves the flag alone when the type stays put" do
      address = create(:address, addressable: organization, address_type: "work", invoice_address: true)

      address.update!(city: "Missoula")

      expect(address).to be_invoice_address
    end
  end

  describe ".ranked_for_owner" do
    let(:person) { create(:person) }

    def address_typed(type, inactive: false, city: type.to_s)
      create(:address, addressable: person, address_type: type, inactive: inactive, city: city)
    end

    it "prefers the active work address" do
      address_typed("personal")
      work = address_typed("work")

      expect(person.addresses.ranked_for_owner.first).to eq(work)
    end

    it "falls back to the most recently edited active personal address" do
      older = address_typed("personal", city: "Boise")
      newer = address_typed("personal", city: "Nampa")
      older.update!(zip_code: "83701")
      newer.update!(zip_code: "83651")

      expect(person.addresses.ranked_for_owner.first).to eq(newer)
    end

    it "takes an untyped active address over any retired one" do
      address_typed("work", inactive: true)
      unknown = address_typed(Address::UNKNOWN_CONTACT_TYPE)

      expect(person.addresses.ranked_for_owner.first).to eq(unknown)
    end

    # A retired work address is the stalest thing we hold — people change jobs,
    # and home outlasts the job — so it sorts behind a retired personal one.
    it "prefers a retired personal address to a retired work address" do
      address_typed("work", inactive: true)
      personal = address_typed("personal", inactive: true)

      expect(person.addresses.ranked_for_owner.first).to eq(personal)
    end
  end

  describe ".unfilled_attributes?" do
    it "is true for a block carrying only the pre-filled country, state, and locality" do
      attrs = { "country" => "Canada", "state" => "AB", "locality" => "Outside USA",
                "city" => "", "street_address" => "", "zip_code" => "" }.with_indifferent_access

      expect(described_class.unfilled_attributes?(attrs)).to be(true)
    end

    it "is false once a typed field is filled in" do
      attrs = { "city" => "Calgary", "street_address" => "", "zip_code" => "" }.with_indifferent_access

      expect(described_class.unfilled_attributes?(attrs)).to be(false)
    end
  end

  describe "an unfilled nested address block" do
    it "is dropped rather than failing the organization it was added to" do
      organization = create(:organization)
      create(:address, addressable: organization, city: "Albany", state: "NY",
                       country: "United States", locality: "Outside CA")

      saved = organization.update(addresses_attributes: {
        "0" => { "locality" => "Outside CA", "state" => "NY", "country" => "United States",
                 "city" => "", "street_address" => "", "zip_code" => "" }
      })

      expect(saved).to be(true)
      expect(organization.addresses.reload.count).to eq(1)
    end
  end
end
