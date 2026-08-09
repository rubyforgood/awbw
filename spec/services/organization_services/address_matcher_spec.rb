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
    same_street = create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "Texas")

    expect(described_class.call(organization, city: "Austin", state: "TX", street_address: "1 Main St")).to eq(same_street)
  end

  it "prefers a state match over a street match" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "Texas")
    by_state = create(:address, addressable: organization, street_address: "9 Other Rd", city: "Austin", state: "TX")

    expect(described_class.call(organization, city: "Austin", state: "TX", street_address: "1 Main St")).to eq(by_state)
  end

  it "returns nil when neither state nor street matches" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX")

    expect(described_class.call(organization, city: "Austin", state: "CA", street_address: "99 Nowhere Ln")).to be_nil
  end

  it "falls back across cities to the same street and ZIP when the city is respelled" do
    respelled = create(:address, addressable: organization, street_address: "1 Main St", city: "Saint Louis", state: "MO", zip_code: "63101")

    match = described_class.call(organization, city: "St. Louis", state: "MO", street_address: "1 Main St", zip_code: "63101")

    expect(match).to eq(respelled)
  end

  it "does not merge two offices on the same street in different cities when the ZIP differs" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Dallas", state: "TX", zip_code: "75201")

    match = described_class.call(organization, city: "Austin", state: "TX", street_address: "1 Main St", zip_code: "78701")

    expect(match).to be_nil
  end

  it "does not fall back across cities without a submitted ZIP" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Saint Louis", state: "MO", zip_code: "63101")

    expect(described_class.call(organization, city: "St. Louis", state: "MO", street_address: "1 Main St")).to be_nil
  end

  it "prefers the in-city match over a cross-city street/ZIP one" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Saint Louis", state: "MO", zip_code: "63101")
    in_city = create(:address, addressable: organization, street_address: "9 Other Rd", city: "St. Louis", state: "MO", zip_code: "63102")

    match = described_class.call(organization, city: "St. Louis", state: "MO", street_address: "1 Main St", zip_code: "63101")

    expect(match).to eq(in_city)
  end
end
