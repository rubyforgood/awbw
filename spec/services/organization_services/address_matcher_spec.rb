require "rails_helper"

RSpec.describe OrganizationServices::AddressMatcher do
  let(:organization) { create(:organization) }

  it "returns nil when no city is given" do
    create(:address, addressable: organization, city: "Austin", state: "TX")

    expect(described_class.call(organization, city: nil, state: "TX")).to be_nil
  end

  it "returns nil when the org has no address in that city" do
    create(:address, addressable: organization, city: "Dallas", state: "TX")

    expect(described_class.call(organization, city: "Austin", state: "TX")).to be_nil
  end

  it "matches the same city/state address (case-insensitive)" do
    address = create(:address, addressable: organization, city: "Austin", state: "TX")

    expect(described_class.call(organization, city: "austin", state: "tx")).to eq(address)
  end

  it "falls back to the same-street address when the state differs (e.g. by format)" do
    same_street = create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "Tex")

    expect(described_class.call(organization, city: "Austin", state: "TX", street_address: "1 Main St")).to eq(same_street)
  end

  # A different street is a different office, even in the right city and state.
  it "matches the same street in the city rather than a different street with the right state" do
    same_street = create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "Tex")
    create(:address, addressable: organization, street_address: "9 Other Rd", city: "Austin", state: "TX")

    expect(described_class.call(organization, city: "Austin", state: "TX", street_address: "1 Main St")).to eq(same_street)
  end

  it "matches a same-city/state address with no street on file" do
    blank_street = create(:address, addressable: organization, street_address: "", city: "Austin", state: "TX")

    expect(described_class.call(organization, city: "Austin", state: "TX", street_address: "1 Main St")).to eq(blank_street)
  end

  it "does not match a different street in the same city and state" do
    create(:address, addressable: organization, street_address: "9 Other Rd", city: "Austin", state: "TX")

    expect(described_class.call(organization, city: "Austin", state: "TX", street_address: "1 Main St")).to be_nil
  end

  # An org with several offices in one city: the state alone can't tell them
  # apart, so the submitted street has to break the tie or we update the wrong one.
  it "prefers the same-street address when several share the city and state" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701")
    same_street = create(:address, addressable: organization, street_address: "5 Oak Ave", city: "Austin", state: "TX", zip_code: "78702")

    match = described_class.call(organization, city: "Austin", state: "TX", street_address: "5 Oak Ave", zip_code: "78702")

    expect(match).to eq(same_street)
  end

  it "matches known spellings of the city, state, and street" do
    address = create(:address, addressable: organization, street_address: "1 North Main Street", city: "Saint Louis", state: "Missouri")

    match = described_class.call(organization, city: "St. Louis", state: "MO", street_address: "1 N Main St.")

    expect(match).to eq(address)
  end

  it "returns nil when neither state nor street matches" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX")

    expect(described_class.call(organization, city: "Austin", state: "CA", street_address: "99 Nowhere Ln")).to be_nil
  end

  it "falls back across cities to the same street and ZIP when the city is respelled" do
    respelled = create(:address, addressable: organization, street_address: "1 Main St", city: "San Buenaventura", state: "CA", zip_code: "93001")

    match = described_class.call(organization, city: "Ventura", state: "CA", street_address: "1 Main St", zip_code: "93001")

    expect(match).to eq(respelled)
  end

  it "does not merge two offices on the same street in different cities when the ZIP differs" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Dallas", state: "TX", zip_code: "75201")

    match = described_class.call(organization, city: "Austin", state: "TX", street_address: "1 Main St", zip_code: "78701")

    expect(match).to be_nil
  end

  it "does not fall back across cities without a submitted ZIP" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "San Buenaventura", state: "CA", zip_code: "93001")

    expect(described_class.call(organization, city: "Ventura", state: "CA", street_address: "1 Main St")).to be_nil
  end

  it "matches the cross-city same street/ZIP address rather than a different street in the city" do
    cross_city = create(:address, addressable: organization, street_address: "1 Main St", city: "San Buenaventura", state: "CA", zip_code: "93001")
    create(:address, addressable: organization, street_address: "9 Other Rd", city: "Ventura", state: "CA", zip_code: "93002")

    match = described_class.call(organization, city: "Ventura", state: "CA", street_address: "1 Main St", zip_code: "93001")

    expect(match).to eq(cross_city)
  end
end
