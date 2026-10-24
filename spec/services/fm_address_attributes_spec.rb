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

  it "takes the address type the caller gives over the row's" do
    expect(builder.call(row, address_type: "work")).to include(address_type: "work")
  end

  it "reads the county and a missing ZIP from the archive's ZIP table" do
    FmPostalCode.create!(fm_id: "91101", data: { "County" => "Los Angeles" })

    attributes = builder.call(row.merge("AddrsCity" => "Pasadena", "AddrsPostalCode" => nil, "PostalCodeLookup" => "91101"))

    expect(attributes).to include(zip_code: "91101", county: "Los Angeles", locality: Address::LA_COUNTY)
  end

  it "reads a missing country from the state" do
    expect(builder.call(row.merge("AddrsState" => "BC", "AddrsCountry" => nil))).to include(state: "BC", country: "Canada")
  end

  it "skips a row with no street, city, or state" do
    expect(builder.call(row.merge("AddrsLine1" => "", "StreetNo" => "", "AddrsLine2" => ""))).to be_nil
    expect(builder.call(row.merge("AddrsCity" => " "))).to be_nil
    expect(builder.call(row.merge("AddrsState" => nil))).to be_nil
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
