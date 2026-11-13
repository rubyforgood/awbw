require "rails_helper"

RSpec.describe OrganizationServices::UpsertPhone do
  let(:organization) { create(:organization) }

  it "saves nothing for a blank answer" do
    result = described_class.call(organization: organization, phone: "  ")

    expect(result.changes).to be_empty
    expect(organization.contact_methods).to be_empty
  end

  it "adds a new number as the org's primary work phone" do
    result = described_class.call(organization: organization, phone: " 555-400-1000 ")

    expect(result.phone).to have_attributes(contactable: organization, kind: "phone", value: "555-400-1000",
                                            contact_type: "work", primary: true)
    expect(result.changes.map(&:field)).to eq([ "phone" ])
  end

  it "takes the primary flag off the old primary, which stays active, and reports the swap" do
    old = create(:contact_method, contactable: organization, value: "555-400-2000", primary: true)

    result = described_class.call(organization: organization, phone: "555-400-1000")

    expect(old.reload).to have_attributes(primary: false, inactive: false)
    swap = result.changes.find { |change| change.field == "primary_phone" }
    expect(swap).to have_attributes(value: "555-400-1000", previous_value: "555-400-2000")
  end

  it "reuses a number already on file, formatting aside, and reactivates it" do
    held = create(:contact_method, contactable: organization, value: "(555) 400-1000", inactive: true)

    result = described_class.call(organization: organization, phone: "+1 555 400 1000")

    expect(organization.contact_methods.count).to eq(1)
    expect(held.reload).to have_attributes(inactive: false, primary: true)
    expect(result.changes.map(&:field)).to eq([ "phone" ])
  end

  it "doesn't make a reused number primary over the org's current active primary" do
    current = create(:contact_method, contactable: organization, value: "555-400-2000", primary: true)
    held = create(:contact_method, contactable: organization, value: "555-400-1000")

    described_class.call(organization: organization, phone: "555-400-1000")

    expect(current.reload.primary).to be(true)
    expect(held.reload.primary).to be(false)
  end

  it "reports nothing when the number is already the org's active primary" do
    create(:contact_method, contactable: organization, value: "555-400-1000", primary: true)

    result = described_class.call(organization: organization, phone: "555-400-1000")

    expect(result.changes).to be_empty
  end
end
