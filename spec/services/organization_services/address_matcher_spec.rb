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
end
