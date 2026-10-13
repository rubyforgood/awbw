require "rails_helper"

RSpec.describe FmPeopleToOrganizationDecorator do
  it "reads as the person's title at the organization" do
    FmOrganization.create!(fm_id: "ORG1", data: { "OrgName" => "Sample Shelter" })
    affiliation = FmPeopleToOrganization.new(data: { "OrgID" => "ORG1", "Title" => "Case Manager" }).decorate

    expect([ affiliation.kind, affiliation.summary ]).to eq([ "Case Manager", "Sample Shelter" ])
  end

  it "falls back to the organization ID when the archive lacks the organization" do
    affiliation = FmPeopleToOrganization.new(data: { "OrgID" => "ORG9", "Title" => "" }).decorate

    expect([ affiliation.kind, affiliation.summary ]).to eq([ "Affiliation", "ORG9" ])
  end
end
