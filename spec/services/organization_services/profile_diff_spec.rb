require "rails_helper"

RSpec.describe OrganizationServices::ProfileDiff do
  let(:organization) { create(:organization) }

  it "returns no discrepancies when there is nothing submitted" do
    organization.update!(organization_type: "For-profit", website_url: "https://acme.org")

    expect(described_class.call(organization: organization)).to be_empty
  end

  it "does not flag a submitted value against a blank org column (it just gets filled)" do
    organization.update!(organization_type: nil, website_url: nil)

    diff = described_class.call(organization: organization, website: "acme.org", organization_type: "For-profit")

    expect(diff).to be_empty
  end

  it "does not flag a website that matches apart from scheme/www/trailing slash" do
    organization.update!(website_url: "https://www.acme.org/")

    diff = described_class.call(organization: organization, website: "acme.org")

    expect(diff).to be_empty
  end

  # The sync never saves a non-address answer, so the admin should see it wasn't applied.
  it "flags a website answer that isn't a web address" do
    organization.update!(website_url: "https://acme.org")

    diff = described_class.call(organization: organization, website: "Acme Unified School District")

    expect(diff.first).to have_attributes(field: :website_url, submitted: "Acme Unified School District", saved: "https://acme.org",
                                          reason: "not a web address")
    expect(diff.first.summary).to eq("form: “Acme Unified School District”, saved: “https://acme.org” — not a web address")
  end

  it "flags a website answer that isn't a web address even when the org has no website" do
    organization.update!(website_url: nil)

    diff = described_class.call(organization: organization, website: "Acme Unified School District")

    expect(diff.first).to have_attributes(field: :website_url, saved: nil, reason: "not a web address")
    expect(diff.first.summary).to eq("form: “Acme Unified School District” — not a web address")
  end

  it "flags a website that differs from the saved one" do
    organization.update!(website_url: "https://acme.org")

    diff = described_class.call(organization: organization, website: "https://other.org")

    expect(diff.map(&:field)).to eq([ :website_url ])
    expect(diff.first).to have_attributes(label: "Website", submitted: "https://other.org", saved: "https://acme.org")
  end

  it "flags a type that differs from the saved one" do
    organization.update!(organization_type: "501c3/nonprofit")

    diff = described_class.call(organization: organization, organization_type: "Government agency")

    expect(diff.map(&:field)).to eq([ :organization_type ])
    expect(diff.first).to have_attributes(label: "Type", submitted: "Government agency", saved: "501c3/nonprofit")
  end

  it "compares an 'Other: <text>' submission against the saved label + free text" do
    organization.update!(organization_type: "Other", organization_type_other: "Equine therapy")

    same = described_class.call(organization: organization, organization_type: "Other: Equine therapy")
    expect(same).to be_empty

    different = described_class.call(organization: organization, organization_type: "Other: Art therapy")
    expect(different.first).to have_attributes(label: "Type", submitted: "Other: Art therapy", saved: "Other: Equine therapy")
  end

  it "flags both type and website when both differ" do
    organization.update!(organization_type: "For-profit", website_url: "https://acme.org")

    diff = described_class.call(organization: organization, website: "https://other.org", organization_type: "Government agency")

    expect(diff.map(&:field)).to contain_exactly(:website_url, :organization_type)
  end

  it "reads website, type, and address from an org entry" do
    organization.update!(organization_type: "For-profit", website_url: "https://acme.org")
    entry = FormSubmission.org_entry_from("organization_website" => "https://other.org", "organization_type" => "Government agency")

    diff = described_class.for_entry(organization: organization, entry: entry)

    expect(diff.map(&:field)).to contain_exactly(:website_url, :organization_type)
  end

  describe "address" do
    it "flags ZIP and country that differ from the org's same-street address" do
      create(:address, addressable: organization, street_address: "5 Oak Ave", city: "Austin", state: "TX", zip_code: "78701", country: "USA")

      diff = described_class.call(organization: organization, address: {
        street_address: "5 Oak Ave", city: "Austin", state: "TX", zip_code: "78702", country: "Canada"
      })

      expect(diff.map(&:field)).to contain_exactly(:address_zip, :address_country)
      zip = diff.find { |d| d.field == :address_zip }
      expect(zip).to have_attributes(label: "Address – ZIP", submitted: "78702", saved: "78701")
    end

    it "does not flag a different street in the same city (it's added as a new address)" do
      create(:address, addressable: organization, street_address: "5 Oak Ave", city: "Austin", state: "TX", zip_code: "78701")

      diff = described_class.call(organization: organization, address: { street_address: "1 Main St", city: "Austin", state: "TX" })

      expect(diff).to be_empty
    end

    it "does not flag address fields that match (case/whitespace insensitive)" do
      create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701")

      diff = described_class.call(organization: organization, address: {
        street_address: " 1 main st ", city: "austin", state: "tx", zip_code: "78701"
      })

      expect(diff).to be_empty
    end

    it "does not flag a street that differs only in spelling the address matcher treats as the same" do
      create(:address, addressable: organization, street_address: "12 E Main St.", city: "Austin", state: "TX", zip_code: "78701")

      diff = described_class.call(organization: organization, address: {
        street_address: "12 East Main Street", city: "Austin", state: "TX", zip_code: "78701"
      })

      expect(diff).to be_empty
    end

    # A legacy row can hold a padded street/ZIP, and comparing it to the trimmed
    # answer would flag the address as unreconciled against its own value.
    it "does not flag a saved value that differs only by surrounding whitespace" do
      create(:address, addressable: organization, street_address: " 1 Main St ", city: "Austin", state: "TX", zip_code: " 78701 ")

      diff = described_class.call(organization: organization, address: {
        street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701"
      })

      expect(diff).to be_empty
    end

    it "flags a city that differs on the address matched across cities by street and ZIP" do
      create(:address, addressable: organization, street_address: "1 Main St", city: "Saint Louis", state: "MO", zip_code: "63101")

      diff = described_class.call(organization: organization, address: {
        street_address: "1 Main St", city: "St. Louis", state: "MO", zip_code: "63101"
      })

      expect(diff.map(&:field)).to eq([ :address_city ])
      expect(diff.first).to have_attributes(label: "Address – city", submitted: "St. Louis", saved: "Saint Louis")
    end

    it "does not flag a submitted address in a city the org has no address for (it gets added, not reconciled)" do
      create(:address, addressable: organization, city: "Dallas", state: "TX")

      diff = described_class.call(organization: organization, address: {
        street_address: "1 Main St", city: "Austin", state: "TX"
      })

      expect(diff).to be_empty
    end

    it "flags an address with no city, which can't be saved" do
      diff = described_class.call(organization: organization, address: { street_address: "1 Main St", zip_code: "78701" })

      expect(diff.sole).to have_attributes(field: :address, label: "Address", submitted: "1 Main St, 78701", saved: nil,
                                           reason: "no city, so it wasn't saved")
    end

    it "flags an address with no state that matches none of the org's addresses, which can't be saved" do
      create(:address, addressable: organization, city: "Dallas", state: "TX")

      diff = described_class.call(organization: organization, address: { street_address: "1 Main St", city: "Austin" })

      expect(diff.sole).to have_attributes(field: :address, submitted: "1 Main St, Austin", reason: "no state, so it wasn't saved")
      expect(diff.sole.summary).to eq("form: “1 Main St, Austin” — no state, so it wasn't saved")
    end

    it "does not flag a stateless address that matches one the org already has (it updates that one)" do
      create(:address, addressable: organization, street_address: "1 Main St", city: "Austin", state: "TX")

      diff = described_class.call(organization: organization, address: { street_address: "1 Main St", city: "Austin" })

      expect(diff).to be_empty
    end

    it "does not flag a field that is blank on the org's address" do
      create(:address, addressable: organization, street_address: "", city: "Austin", state: "TX")

      diff = described_class.call(organization: organization, address: {
        street_address: "1 Main St", city: "Austin", state: "TX"
      })

      expect(diff).to be_empty
    end
  end
end
