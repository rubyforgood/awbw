require "rails_helper"

RSpec.describe FmAddressAttributes do
  subject(:builder) { described_class.new }

  let(:row) do
    { "StreetNo" => "1234", "AddrsLine1" => "Main St", "AddrsLine2" => "Apt 2", "AddrsCity" => "Los Angeles",
      "AddrsState" => "California", "AddrsPostalCode" => "90001", "AddrsCountry" => "USA", "AddrsType" => "Home" }
  end

  it "builds translated address attributes from an archive row" do
    expect(builder.call(row)).to eq(
      street_address: "1234 Main St, Apt 2", city: "Los Angeles", state: "CA", zip_code: "90001",
      country: "United States", county: nil, address_type: "personal", locality: Address::LA_CITY
    )
  end

  it "types an organization's address as work, marking the one the archive calls mailing as its invoice address" do
    expect(builder.call(row.merge("AddrsType" => "Postal"), organization: true)).to include(address_type: "work", invoice_address: true)
    expect(builder.call(row, organization: true)).to include(address_type: "work", invoice_address: false)
  end

  it "reads the county and a missing ZIP from the archive's ZIP table" do
    FmPostalCode.create!(fm_id: "91101", data: { "County" => "Los Angeles" })

    attributes = builder.call(row.merge("AddrsCity" => "Pasadena", "AddrsPostalCode" => nil, "PostalCodeLookup" => "91101"))

    expect(attributes).to include(zip_code: "91101", county: "Los Angeles", locality: Address::LA_COUNTY)
  end

  it "reads a missing country from the state" do
    expect(builder.call(row.merge("AddrsState" => "BC", "AddrsCountry" => nil))).to include(state: "BC", country: "Canada")
  end

  it "builds a row with no street from its city and state" do
    expect(builder.call(row.merge("AddrsLine1" => "", "StreetNo" => "", "AddrsLine2" => "")))
      .to include(street_address: "", city: "Los Angeles", state: "CA")
  end

  it "skips a row with no city or state" do
    expect(builder.call(row.merge("AddrsCity" => " "))).to be_nil
    expect(builder.call(row.merge("AddrsState" => nil))).to be_nil
  end

  describe ".held" do
    let(:held) { build(:address, street_address: "1234 Main Street", city: "Los Angeles") }

    it "finds the address on file for the same street in the same city" do
      expect(described_class.held([ held ], street_address: "1234 Main St", city: "los angeles")).to eq(held)
      expect(described_class.held([ held ], street_address: "9 Elm St", city: "Los Angeles")).to be_nil
    end

    it "takes any address in the city for a row with no street" do
      expect(described_class.held([ held ], street_address: "", city: "Los Angeles")).to eq(held)
      expect(described_class.held([ held ], street_address: "", city: "Pasadena")).to be_nil
    end
  end

  describe "#place" do
    it "builds a street-less address for a city and state, translated" do
      expect(builder.place(city: "Toronto", state: "Ontario")).to eq(
        street_address: "", zip_code: "", city: "Toronto", state: "Ontario", country: "Canada",
        county: nil, address_type: nil, locality: Address::OUTSIDE_USA
      )
      expect(builder.place(city: "Fresno", state: "California", county: "Fresno")).to include(state: "CA", country: "United States")
    end
  end

  it "reports the values it can't translate" do
    builder.call(row.merge("AddrsCountry" => "Narnia", "AddrsState" => "ZZ"))

    expect(builder.unmatched[:country]).to eq("Narnia" => 1)
  end
end
