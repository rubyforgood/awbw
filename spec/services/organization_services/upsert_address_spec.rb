require "rails_helper"

RSpec.describe OrganizationServices::UpsertAddress do
  let(:organization) { create(:organization) }

  it "creates a primary work address from the submitted fields" do
    address = described_class.call(
      organization: organization,
      street_address: "1 Main St",
      city: "Austin",
      state: "TX",
      zip_code: "78701",
      country: "USA"
    )

    expect(address).to have_attributes(
      addressable: organization,
      street_address: "1 Main St",
      city: "Austin",
      state: "TX",
      zip_code: "78701",
      country: "USA",
      address_type: "work",
      primary: true
    )
  end

  it "returns nil and creates nothing when no city is given" do
    expect {
      expect(described_class.call(organization: organization, street_address: "1 Main St")).to be_nil
    }.not_to change { organization.addresses.count }
  end

  it "updates the matching city/state address in place instead of duplicating" do
    existing = create(:address, addressable: organization, city: "Austin", state: "TX", primary: true)

    result = described_class.call(
      organization: organization,
      street_address: "2 New Ave",
      city: "austin",
      state: "tx",
      zip_code: "78702",
      country: "Canada"
    )

    expect(result).to eq(existing)
    expect(organization.addresses.count).to eq(1)
    expect(existing.reload).to have_attributes(street_address: "2 New Ave", zip_code: "78702", country: "Canada", primary: true, inactive: false)
  end

  it "leaves the org's existing primary intact and adds the new-city address as non-primary" do
    old_primary = create(:address, addressable: organization, city: "Dallas", state: "TX", primary: true)

    described_class.call(organization: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701")

    expect(old_primary.reload).to have_attributes(primary: true, inactive: false)
    expect(organization.addresses.find_by(city: "Austin")).to have_attributes(primary: false)
  end
end
