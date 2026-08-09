require "rails_helper"

RSpec.describe OrganizationServices::ProfileDiff do
  let(:organization) { create(:organization) }

  it "returns no discrepancies when there is nothing submitted" do
    organization.update!(agency_type: "For-profit", website_url: "https://acme.org")

    expect(described_class.call(organization: organization)).to be_empty
  end

  it "does not flag a submitted value against a blank org column (it just gets filled)" do
    organization.update!(agency_type: nil, website_url: nil)

    diff = described_class.call(organization: organization, website: "acme.org", agency_type: "For-profit")

    expect(diff).to be_empty
  end

  it "does not flag a website that matches apart from scheme/www/trailing slash" do
    organization.update!(website_url: "https://www.acme.org/")

    diff = described_class.call(organization: organization, website: "acme.org")

    expect(diff).to be_empty
  end

  it "flags a website that differs from the saved one" do
    organization.update!(website_url: "https://acme.org")

    diff = described_class.call(organization: organization, website: "https://other.org")

    expect(diff.map(&:field)).to eq([ :website_url ])
    expect(diff.first).to have_attributes(label: "Website", submitted: "https://other.org", saved: "https://acme.org")
  end

  it "flags a type that differs from the saved one" do
    organization.update!(agency_type: "501c3/nonprofit")

    diff = described_class.call(organization: organization, agency_type: "Government agency")

    expect(diff.map(&:field)).to eq([ :agency_type ])
    expect(diff.first).to have_attributes(label: "Type", submitted: "Government agency", saved: "501c3/nonprofit")
  end

  it "compares an 'Other: <text>' submission against the saved label + free text" do
    organization.update!(agency_type: "Other", agency_type_other: "Equine therapy")

    same = described_class.call(organization: organization, agency_type: "Other: Equine therapy")
    expect(same).to be_empty

    different = described_class.call(organization: organization, agency_type: "Other: Art therapy")
    expect(different.first).to have_attributes(label: "Type", submitted: "Other: Art therapy", saved: "Other: Equine therapy")
  end

  it "flags both type and website when both differ" do
    organization.update!(agency_type: "For-profit", website_url: "https://acme.org")

    diff = described_class.call(organization: organization, website: "https://other.org", agency_type: "Government agency")

    expect(diff.map(&:field)).to contain_exactly(:website_url, :agency_type)
  end
end
