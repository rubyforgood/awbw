# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddressServices::DuplicateFinder do
  let(:attrs) do
    {
      street_address: "1 Main St", city: "Springfield", state: "CA", zip_code: "90001",
      country: "USA", county: "LA", district: nil, address_type: "work", locality: "LA City"
    }
  end

  it "groups an owner's addresses that share a signature" do
    org = create(:organization)
    first = create(:address, addressable: org, **attrs)
    second = create(:address, addressable: org, **attrs, street_address: " 1 MAIN ST ")
    create(:address, addressable: org, **attrs, street_address: "2 Other St")

    groups = described_class.new.groups

    expect(groups.map(&:addressable)).to eq([ org ])
    expect(groups.first.duplicate_sets).to eq([ [ first, second ] ])
    expect(groups.first.folded_count).to eq(1)
  end

  it "ignores the same address on different owners" do
    create(:address, addressable: create(:organization), **attrs)
    create(:address, addressable: create(:person), **attrs)

    expect(described_class.new.groups).to be_empty
  end

  it "labels a person by full name" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace")
    2.times { create(:address, addressable: person, **attrs) }

    expect(described_class.new.groups.first.label).to eq(person.full_name)
  end
end
