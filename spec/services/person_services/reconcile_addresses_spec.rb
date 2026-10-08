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

  it "folds into the active copy when an older duplicate is inactive" do
    inactive = address(inactive: true)
    active = address

    described_class.new(person).call

    expect(person.addresses.reload.pluck(:id)).to eq([ active.id ])
    expect(person.addresses.active.count).to eq(1)
    expect(Address.exists?(inactive.id)).to be false
  end

  it "folds into the primary copy when the duplicate is not primary" do
    plain = address
    primary = address(primary: true)

    described_class.new(person).call

    expect(person.addresses.reload.pluck(:id)).to eq([ primary.id ])
    expect(Address.exists?(plain.id)).to be false
  end

  it "carries a folded address's phone onto a survivor that has none" do
    keep = address
    address(phone: "555-9000")

    described_class.new(person).call

    expect(keep.reload.phone).to eq("555-9000")
  end

  it "leaves the survivor's own phone alone when the duplicate also has one" do
    keep = address(phone: "555-1000")
    address(phone: "555-9000")

    described_class.new(person).call

    expect(keep.reload.phone).to eq("555-1000")
  end

  it "carries a folded address's geocoded districts onto a survivor that has none" do
    keep = address(la_city_council_district: nil, la_service_planning_area: nil, la_supervisorial_district: nil)
    address(la_city_council_district: 4, la_service_planning_area: 2, la_supervisorial_district: 3)

    described_class.new(person).call

    expect(keep.reload.la_city_council_district).to eq(4)
    expect(keep.la_service_planning_area).to eq(2)
    expect(keep.la_supervisorial_district).to eq(3)
  end
end
