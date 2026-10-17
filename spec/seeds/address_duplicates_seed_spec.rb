require "rails_helper"

RSpec.describe "dev seed: address_duplicates" do
  let(:seed) { Rails.root.join("db/seeds/dev/address_duplicates.rb") }
  let(:sampler) { Organization.find_by!(name: "Address Dedupe Sampler (seed)") }

  def cities_after_merge(owner)
    AddressDeduper.merge_duplicates(owner)
    owner.addresses.reload.group_by(&:city).transform_values(&:size)
  end

  it "lists a duplicate set for every matching rule" do
    load seed

    groups = AddressServices::DuplicateFinder.new.groups
    expect(groups.size).to eq(2)
    expect(groups.sum(&:merged_count)).to eq(21)
  end

  it "merges each rule's set to one address and leaves the near-misses apart" do
    load seed

    counts = cities_after_merge(sampler)

    expect(counts.except("Typoville", "Splitburg", "Typeton", "Twin Oaks").values).to all(eq(1))
    expect(counts.slice("Typoville", "Splitburg", "Typeton", "Twin Oaks"))
      .to eq("Typoville" => 2, "Splitburg" => 2, "Typeton" => 2, "Twin Oaks" => 3)
  end

  it "moves the person's phone onto the kept address" do
    load seed
    person = Person.find_by!(first_name: "Dedupe", last_name: "Addresses Sample")

    AddressDeduper.merge_duplicates(person)

    expect(person.contact_methods.sole.address).to eq(person.addresses.reload.sole)
  end

  it "flags the sampler and its neighbor as sharing an address" do
    load seed

    group = OrganizationServices::DuplicateFinder.new.groups.find { |candidate| candidate.records.include?(sampler) }
    expect(group.reasons).to include("Shared address")
  end

  it "skips a second run" do
    load seed

    expect { load seed }.not_to change(Address, :count)
  end
end
