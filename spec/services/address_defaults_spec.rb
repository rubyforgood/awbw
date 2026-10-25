require "rails_helper"

RSpec.describe AddressDefaults do
  before { FmPostalCode.create!(fm_id: "93701", data: { "City" => "Fresno", "State" => "CA", "County" => "Fresno" }) }

  it "fills a US address's country, county and locality from its state and ZIP" do
    expect(described_class.for(city: "Fresno", state: "CA", zip_code: "93701"))
      .to eq(country: "United States", county: "Fresno", locality: "Central CA")
  end

  it "keeps the country and county the address names" do
    expect(described_class.for(city: "Fresno", state: "CA", zip_code: "93701", country: "United States", county: "Madera"))
      .to eq(country: "United States", county: "Madera", locality: "Central CA")
  end

  it "leaves the country blank for a state no US state answers to, and places it Outside USA" do
    expect(described_class.for(city: "Toronto", state: "ON", zip_code: "M5H 2N2"))
      .to eq(country: nil, county: nil, locality: "Outside USA")
  end

  it "skips the ZIP's county for an address outside the US" do
    expect(described_class.for(city: "Fresno", state: "Jalisco", zip_code: "93701", country: "Mexico"))
      .to eq(country: "Mexico", county: nil, locality: "Outside USA")
  end
end
