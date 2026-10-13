require "rails_helper"

RSpec.describe FmAddressDecorator do
  it "reads an address on one line, skipping blank parts" do
    address = FmAddress.new(data: { "AddrsLine1" => "88 Rose Ave", "AddrsLine2" => "", "AddrsCity" => "Venice",
                                    "AddrsState" => "CA", "AddrsPostalCode" => "90291", "AddrsCountry" => "USA" }).decorate

    expect(address.summary).to eq("88 Rose Ave, Venice, CA 90291, USA")
  end

  it "leads with the street number FileMaker stores apart from the street" do
    address = FmAddress.new(data: { "StreetNo" => "88", "AddrsLine1" => "Rose Ave", "AddrsCity" => "Venice" }).decorate

    expect(address.summary).to eq("88 Rose Ave, Venice")
  end

  it "skips a street number the street line already starts with" do
    address = FmAddress.new(data: { "StreetNo" => "88", "AddrsLine1" => "88 Rose Ave", "AddrsCity" => "Venice" }).decorate

    expect(address.summary).to eq("88 Rose Ave, Venice")
  end

  it "falls back to a generic kind when the type is blank" do
    expect(FmAddress.new(data: { "AddrsType" => "" }).decorate.kind).to eq("Address")
  end
end
