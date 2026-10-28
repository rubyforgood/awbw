# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationServices::MergeSameNamed do
  def merge(run: nil)
    described_class.new(run:).call
  end

  def in_city(organization, city)
    create(:address, addressable: organization, city:)
    organization
  end

  it "merges an audience version into the one with the most affiliations, joining codes and dropping the audience word" do
    combined = create(:organization, name: "Harbor House Combined", filemaker_code: "P0001")
    childrens = create(:organization, name: "Harbor House Children's", filemaker_code: "P0002")
    create_list(:affiliation, 2, organization: combined)
    moved = create(:affiliation, organization: childrens)

    results = merge.results

    expect(Organization.exists?(childrens.id)).to be(false)
    expect(combined.reload).to have_attributes(name: "Harbor House", filemaker_code: "P0001, P0002")
    expect(moved.reload.organization).to eq(combined)
    expect(results[:merged].sole).to include("##{childrens.id}", "##{combined.id}")
    expect(results[:renamed].sole).to include("Harbor House Combined", "Harbor House")
  end

  it "merges a newer twin with no code or address, and fills the keeper's blanks from it" do
    coded = create(:organization, name: "Greater Hope Combined", filemaker_code: "P0010")
    create(:affiliation, organization: coded)
    twin = create(:organization, name: "Greater Hope", website_url: "greaterhope.example.org")

    merge

    expect(Organization.exists?(twin.id)).to be(false)
    expect(coded.reload).to have_attributes(name: "Greater Hope", website_url: "greaterhope.example.org")
  end

  it "keeps apart same-name organizations in different cities with no FileMaker parent in common" do
    harbor = in_city(create(:organization, name: "Safe Harbor Combined"), "Sheboygan")
    other = in_city(create(:organization, name: "Safe Harbor, Inc. Women's"), "Easley")

    results = merge.results

    expect(Organization.where(id: [ harbor.id, other.id ]).count).to eq(2)
    expect(results[:kept_apart].sole).to include("##{other.id}", "Sheboygan", "Easley")
  end

  it "merges different cities that share a FileMaker parent, a retired duplicate counting as its original" do
    stub_const("FilemakerValues::RETIRED_DUPLICATE_OF", { "ORG00007" => "ORG00006" })
    FmProject.create!(fm_id: "P0006", data: { "OrgID" => "ORG00006" })
    FmProject.create!(fm_id: "P0007", data: { "OrgID" => "ORG00007" })
    keeper = in_city(create(:organization, name: "Valley Clinics Combined", filemaker_code: "P0006"), "Pomona")
    create(:affiliation, organization: keeper)
    other = in_city(create(:organization, name: "Valley Clinics Children's", filemaker_code: "P0007"), "Santa Fe Springs")

    merge

    expect(Organization.exists?(other.id)).to be(false)
    expect(keeper.reload.filemaker_code).to eq("P0006, P0007")
  end

  it "reads a FileMaker project's city as the organization's" do
    FmProject.create!(fm_id: "P0020", data: { "City" => "Ojai" })
    keeper = create(:organization, name: "Twin Oaks Combined", filemaker_code: "P0020")
    create(:affiliation, organization: keeper)
    other = in_city(create(:organization, name: "Twin Oaks Women's"), "Ojai")

    merge

    expect(Organization.exists?(other.id)).to be(false)
  end

  it "keeps the audience word when an organization kept apart holds the shorter name" do
    keeper = in_city(create(:organization, name: "Avalon Center Combined"), "Williamsburg")
    create(:affiliation, organization: keeper)
    in_city(create(:organization, name: "Avalon Center"), "Crossville")

    results = merge.results

    expect(keeper.reload.name).to eq("Avalon Center Combined")
    expect(results[:renamed]).to be_empty
  end

  it "keeps a real name ending in Youth or Women whole" do
    keeper = create(:organization, name: "Safe Place for Youth Combined")
    create(:affiliation, organization: keeper)
    create(:organization, name: "Safe Place for Youth")
    create(:organization, name: "Safe Place for Women")

    merge

    expect(keeper.reload.name).to eq("Safe Place for Youth")
    expect(Organization.where(name: "Safe Place for Women")).to exist
  end

  it "tags its activity with the run, and none of it as an import run fm:undo_import would reverse" do
    keeper = create(:organization, name: "Harbor House Combined")
    create(:affiliation, organization: keeper)
    create(:organization, name: "Harbor House Women's")
    Current.source = "fm_merge_same_named_organizations"

    merge(run: "fm-merge-1")

    events = Ahoy::Event.where("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.merge_run')) = ?", "fm-merge-1")
    expect(events.pluck(:name)).to include("dedupe.organization")
    expect(Ahoy::Event.where("JSON_EXTRACT(properties, '$.import_run') IS NOT NULL")).to be_empty
  ensure
    Current.reset
  end
end
