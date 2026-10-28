require "rails_helper"

RSpec.describe DataHealth::FilemakerNotImported do
  subject(:not_imported) { described_class.new }

  def kind(key) = described_class.kind(key)

  def missing(key) = not_imported.page(kind(key), 1).map(&:fm_id)

  it "lists Rolodex cards no person carries the code of" do
    FmRolodex.create!(fm_id: "00006", data: { "FirstName" => "Ada" })
    FmRolodex.create!(fm_id: "00007", data: { "FirstName" => "Grace" })
    FmRolodex.create!(fm_id: "00008", data: { "FirstName" => "Alan" })
    create(:person, filemaker_code: "00006, 00008")

    expect(missing("people")).to eq([ "00007" ])
    expect(not_imported.count(kind("people"))).to eq(1)
  end

  it "counts an FM organization as imported when an org carries one of its projects' codes" do
    FmOrganization.create!(fm_id: "ORG00001", data: {})
    FmOrganization.create!(fm_id: "ORG00002", data: {})
    FmOrganization.create!(fm_id: "ORG00003", data: {})
    FmProject.create!(fm_id: "P0001", data: { "OrgID" => "ORG00002" })
    FmProject.create!(fm_id: "P0002", data: { "OrgID" => "ORG00003" })
    create(:organization, filemaker_code: "ORG00001")
    create(:organization, filemaker_code: "P0001")

    expect(missing("organizations")).to eq([ "ORG00003" ])
    expect(missing("programs")).to eq([ "P0002" ])
  end

  it "reads personnel and job rows against affiliation codes" do
    FmPersonnel.create!(fm_id: "PS0028", data: {})
    FmPersonnel.create!(fm_id: "PS0029", data: {})
    FmPeopleToOrganization.create!(fm_id: "1", data: {})
    FmPeopleToOrganization.create!(fm_id: "2", data: {})
    create(:affiliation, filemaker_code: "PS0028, 2")

    expect(missing("personnel")).to eq([ "PS0029" ])
    expect(missing("jobs")).to eq([ "1" ])
  end

  it "orders unpadded and widening ids numerically" do
    %w[100 9 10].each { |id| FmPeopleToOrganization.create!(fm_id: id, data: {}) }
    %w[PS10667 PS0028].each { |id| FmPersonnel.create!(fm_id: id, data: {}) }

    expect(missing("jobs")).to eq(%w[9 10 100])
    expect(missing("personnel")).to eq(%w[PS0028 PS10667])
  end

  it "pages through the missing rows" do
    (1..(described_class::PER_PAGE + 2)).each { |n| FmPeopleToOrganization.create!(fm_id: n.to_s, data: {}) }

    second = not_imported.page(kind("jobs"), 2)

    expect(second.total_entries).to eq(described_class::PER_PAGE + 2)
    expect(second.map(&:fm_id)).to eq([ (described_class::PER_PAGE + 1).to_s, (described_class::PER_PAGE + 2).to_s ])
  end

  it "falls back to organizations for an unknown kind" do
    expect(described_class.kind("nope").key).to eq("organizations")
  end
end
