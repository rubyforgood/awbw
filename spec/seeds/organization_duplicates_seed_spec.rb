require "rails_helper"

RSpec.describe "dev seed: organization_duplicates" do
  let(:seed) { Rails.root.join("db/seeds/dev/organization_duplicates.rb") }

  def group_named(prefix)
    OrganizationServices::DuplicateFinder.new.groups.find { |group| group.records.first.name.start_with?(prefix) }
  end

  def names_in(prefix)
    group_named(prefix).records.map(&:name)
  end

  before { load seed }

  it "lists one group per name and FileMaker-code rule" do
    expect(OrganizationServices::DuplicateFinder.new.groups.size).to eq(6)
  end

  it "groups each rule's set and leaves the near-misses out" do
    expect(names_in("Harbor")).to contain_exactly("Harbor Light Shelter", "Harbor-Light Shelter")
    expect(names_in("Maple")).to contain_exactly(
      "Maple Grove Center Children's", "Maple Grove Center Adult", "Maple Grove Center Combined", "Maple Grove Center Women's"
    )
    expect(names_in("Cedar")).to contain_exactly(
      "Cedar Hollow Outreach", "Cedar Hollow Outreach (ORG80002)", "Cedar Hollow Outreach (P8001)"
    )
    expect(names_in("Lakeview").size).to eq(3)
    expect(names_in("Riverbend").size).to eq(2)
  end

  it "flags the FileMaker code in the name" do
    expect(group_named("Cedar").reasons).to include("Same name aside from a FileMaker code in the name")
  end

  it "keeps a shared FileMaker code once when the pair is combined" do
    codes = group_named("Sunrise").records.map(&:filemaker_code)

    expect(Organization.join_filemaker_codes(*codes)).to eq("ORG80005, P8002, P8003")
  end

  it "is a no-op when run again" do
    expect { load seed }.not_to change(Organization, :count)
  end
end
