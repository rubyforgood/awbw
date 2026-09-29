# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::ReconcileAddresses do
  let(:person) { create(:person) }

  def address(primary: false, **overrides)
    attrs = {
      street_address: "1 Main St", city: "Springfield", state: "CA",
      zip_code: "90001", country: "USA", county: "LA", district: nil,
      address_type: "work", locality: "LA City"
    }.merge(overrides)
    create(:address, addressable: person, primary: primary, **attrs)
  end

  it "folds identical addresses into one" do
    keep = address
    dup = address

    described_class.new(person).call

    expect(person.addresses.reload.pluck(:id)).to eq([ keep.id ])
    expect(Address.exists?(dup.id)).to be false
  end

  it "keeps addresses that differ in any detail" do
    address
    address(street_address: "2 Other St")

    described_class.new(person).call

    expect(person.addresses.reload.count).to eq(2)
  end

  it "repoints a folded address's contact methods onto the survivor" do
    keep = address
    dup = address
    method = create(:contact_method, contactable: person, address: dup)

    described_class.new(person).call

    expect(method.reload.address_id).to eq(keep.id)
  end

  it "keeps a single primary matching the given signature and demotes the rest" do
    keep = address(primary: true)
    other = address(street_address: "2 Other St", primary: true)

    described_class.new(person, primary_signature: described_class.signature(keep)).call

    expect(keep.reload.primary?).to be true
    expect(other.reload.primary?).to be false
  end
end
