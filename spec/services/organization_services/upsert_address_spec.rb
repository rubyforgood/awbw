require "rails_helper"

RSpec.describe OrganizationServices::UpsertAddress do
  let(:organization) { create(:organization) }

  it "creates a primary work address from the submitted fields" do
    result = described_class.call(
      organization: organization,
      street_address: "1 Main St",
      city: "Austin",
      state: "TX",
      zip_code: "78701",
      country: "USA"
    )

    expect(result).to have_attributes(created: true)
    expect(result.address).to have_attributes(
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

  # Browsers don't trim text inputs, and a padded value stored verbatim would read
  # as a difference to ProfileDiff and get re-reported as filled on every relink.
  it "strips the submitted street and ZIP before storing them" do
    result = described_class.call(organization: organization, street_address: " 1 Main St ", city: "Austin", state: "TX", zip_code: " 78701 ")

    expect(result.address).to have_attributes(street_address: "1 Main St", zip_code: "78701")
  end

  it "reports nothing filled when the submission only pads what is already on file" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701")

    result = described_class.call(organization: organization, street_address: " 1 Main St ", city: "Austin", state: "TX", zip_code: " 78701 ")

    expect(result).to have_attributes(created: false, changes: [])
  end

  # street and ZIP are NOT NULL columns with no default.
  it "stores skipped street and ZIP answers as empty strings rather than failing" do
    result = described_class.call(organization: organization, city: "Austin", state: "TX")

    expect(result.address).to have_attributes(city: "Austin", state: "TX", street_address: "", zip_code: "")
  end

  # An Address validates city and state, so there is nothing storable without both.
  it "saves nothing when no state was submitted and no existing address matches" do
    expect {
      expect(described_class.call(organization: organization, street_address: "1 Main St", city: "Austin"))
        .to have_attributes(address: nil, created: false, changes: [])
    }.not_to change { organization.addresses.count }
  end

  it "still updates a matching address when the submission skipped the state" do
    existing = create(:address, addressable: organization, street_address: "5 Oak Ave", city: "Austin", state: "TX", zip_code: "")

    result = described_class.call(organization: organization, street_address: "5 Oak Ave", city: "Austin", zip_code: "78701", overwrite: false)

    expect(result).to have_attributes(address: existing, created: false)
    expect(result.changes.map(&:label)).to eq([ "ZIP" ])
    expect(existing.reload.zip_code).to eq("78701")
  end

  it "does not rewrite a different office when the org has two addresses in one city" do
    other_office = create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701")
    submitted_office = create(:address, addressable: organization, street_address: "5 Oak Ave", city: "Austin", state: "TX", zip_code: "78702")

    result = described_class.call(
      organization: organization, street_address: "5 Oak Ave", city: "Austin", state: "TX", zip_code: "78702"
    )

    expect(result.address).to eq(submitted_office)
    expect(other_office.reload).to have_attributes(street_address: "1 Main St", zip_code: "78701")
  end

  it "returns no address and creates nothing when no city is given" do
    expect {
      expect(described_class.call(organization: organization, street_address: "1 Main St"))
        .to have_attributes(address: nil, created: false, changes: [])
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

    expect(result).to have_attributes(address: existing, created: false)
    expect(result.changes.map(&:label)).to contain_exactly("Street", "ZIP", "Country")
    expect(organization.addresses.count).to eq(1)
    expect(existing.reload).to have_attributes(street_address: "2 New Ave", zip_code: "78702", country: "Canada", primary: true, inactive: false)
  end

  it "reports nothing filled when the submission repeats what is already on file" do
    create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701", primary: true)

    result = described_class.call(
      organization: organization,
      street_address: "1 Main St",
      city: "Austin",
      state: "TX",
      zip_code: "78701"
    )

    expect(result).to have_attributes(created: false, changes: [])
  end

  it "fills only blank fields on the matching address when overwrite is false" do
    existing = create(:address, addressable: organization, street_address: "5 Oak Ave", city: "Austin", state: "TX", zip_code: "", country: "", primary: true)

    result = described_class.call(
      organization: organization,
      street_address: "1 Main St",
      city: "Austin",
      state: "TX",
      zip_code: "78702",
      country: "Canada",
      overwrite: false
    )

    expect(result.changes.map(&:label)).to contain_exactly("ZIP", "Country")
    expect(existing.reload).to have_attributes(street_address: "5 Oak Ave", zip_code: "78702", country: "Canada")
  end

  # city and state are NOT NULL and validated present, so only a legacy row holds
  # "". AddressMatcher's street + ZIP last resort is the one path that reaches such
  # a row (the earlier steps all require the city to match), which is why the
  # fill-blank branches for city and state exist.
  it "repairs a legacy address whose city and state are blank" do
    existing = create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701")
    # The presence validations that keep these filled today didn't always exist.
    existing.update_columns(city: "", state: "")

    result = described_class.call(
      organization: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701", overwrite: false
    )

    expect(result).to have_attributes(address: existing, created: false)
    expect(result.changes.map(&:label)).to contain_exactly("City", "State")
    expect(existing.reload).to have_attributes(city: "Austin", state: "TX")
    expect(organization.addresses.count).to eq(1)
  end

  # The public flow overwrites details, but city and state stay fill-only there
  # too: rewriting them would move a saved address rather than correct it.
  it "repairs a legacy blank city without moving an address that already has one" do
    elsewhere = create(:address, addressable: organization, street_address: "1 Main St", city: "Saint Louis", state: "MO", zip_code: "63101")

    described_class.call(
      organization: organization, street_address: "1 Main St", city: "St. Louis", state: "MO", zip_code: "63101"
    )

    expect(elsewhere.reload.city).to eq("Saint Louis")
    expect(organization.addresses.count).to eq(1)
  end

  it "updates the same-street address and fills a missing country instead of duplicating when the state differs by format" do
    existing = create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "Texas", zip_code: "78701", country: "")

    result = described_class.call(
      organization: organization,
      street_address: "1 Main St",
      city: "Austin",
      state: "TX",
      country: "USA",
      overwrite: false
    )

    expect(result).to have_attributes(address: existing, created: false)
    expect(organization.addresses.count).to eq(1)
    # State already on file is kept (never flipped); the blank country is filled.
    expect(existing.reload).to have_attributes(state: "Texas", country: "USA", street_address: "1 Main St")
  end

  it "updates the same street/ZIP address instead of duplicating when the city is respelled, keeping the saved city" do
    existing = create(:address, addressable: organization, street_address: "1 Main St", city: "Saint Louis", state: "MO", zip_code: "63101", country: "")

    result = described_class.call(
      organization: organization,
      street_address: "1 Main St",
      city: "St. Louis",
      state: "MO",
      zip_code: "63101",
      country: "USA",
      overwrite: false
    )

    expect(result).to have_attributes(address: existing, created: false)
    expect(organization.addresses.count).to eq(1)
    expect(existing.reload).to have_attributes(city: "Saint Louis", country: "USA")
  end

  it "fills a blank city on the matched address rather than leaving it empty" do
    # City is validated present now, so only a legacy row can be blank.
    existing = create(:address, addressable: organization, street_address: "1 Main St", city: "Nowhere", state: "MO", zip_code: "63101")
    existing.update_column(:city, "")

    result = described_class.call(
      organization: organization,
      street_address: "1 Main St",
      city: "St. Louis",
      zip_code: "63101",
      overwrite: false
    )

    expect(result).to have_attributes(address: existing)
    expect(existing.reload.city).to eq("St. Louis")
  end

  it "leaves the org's existing primary intact and adds the new-city address as non-primary" do
    old_primary = create(:address, addressable: organization, city: "Dallas", state: "TX", primary: true)

    described_class.call(organization: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701")

    expect(old_primary.reload).to have_attributes(primary: true, inactive: false)
    expect(organization.addresses.find_by(city: "Austin")).to have_attributes(primary: false)
  end
end
