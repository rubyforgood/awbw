require "rails_helper"

RSpec.describe FmPersonnelDecorator do
  it "reads as the role in a program at its organization, with its statuses" do
    FmOrganization.create!(fm_id: "ORG1", data: { "OrgName" => "Sample Shelter" })
    FmProject.create!(fm_id: "P1", data: { "ProjectName" => "Adult Windows", "OrgID" => "ORG1" })
    personnel = FmPersonnel.new(data: { "ProjectID" => "P1", "Role" => "Facilitator", "Status" => "Active", "AgreementStatus" => "Signed" }).decorate

    expect([ personnel.kind, personnel.summary ]).to eq([ "Facilitator", "Adult Windows at Sample Shelter · Active · Signed" ])
  end

  it "falls back to the program ID when the archive lacks the program" do
    personnel = FmPersonnel.new(data: { "ProjectID" => "P9" }).decorate

    expect([ personnel.kind, personnel.summary ]).to eq([ "Personnel", "P9" ])
  end
end
