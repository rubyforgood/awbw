# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationServices::ImportFromFilemaker do
  def fm_organization(fm_id, **data)
    FmOrganization.create!(fm_id:, data: { "OrgName" => "Harbor House" }.merge(data.stringify_keys))
  end

  def project(fm_id, org_id, **data)
    FmProject.create!(fm_id:, data: { "OrgID" => org_id, "ProjectName" => "Harbor House Art Program" }.merge(data.stringify_keys))
  end

  def import
    described_class.new.call
  end

  it "keeps an organization with one project as one organization carrying both codes" do
    fm_organization("ORG00001", Website: "harbor.example.org", Mission: "Shelter for all", OrgType: "Nonprofit")
    project("P0001", "ORG00001", City: "Pasadena", State: "CA", County: "Los Angeles", Locality: "la county",
                                 SPA: "SPA 3", LASupervisorialDistrict: "5", District: "Foothills")
    FmAddress.create!(fm_id: "1", data: { "OrgID" => "ORG00001", "AddrsLine1" => "1 Main St", "AddrsCity" => "Pasadena",
                                          "AddrsState" => "CA", "AddrsPostalCode" => "91101" })
    FmPhoneNumber.create!(fm_id: "2", data: { "OrgID" => "ORG00001", "PhoneNumber" => "555-0100" })
    FmEmailAddress.create!(fm_id: "3", data: { "OrgID" => "ORG00001", "EmailAddress" => "Attn: info@harbor.example.org" })

    expect(import.results[:created].size).to eq(1)

    organization = Organization.sole
    expect(organization).to have_attributes(name: "Harbor House", filemaker_code: "ORG00001, P0001", parent_id: nil,
                                            website_url: "harbor.example.org", mission_vision_values: "Shelter for all",
                                            organization_type: "501c3/nonprofit", email: "info@harbor.example.org")
    expect(organization.addresses.sole).to have_attributes(street_address: "1 Main St", city: "Pasadena", zip_code: "91101",
                                                           address_type: "work", primary: true, phone: "555-0100",
                                                           locality: "LA County", district: "Foothills",
                                                           la_service_planning_area: 3, la_supervisorial_district: 5)
  end

  describe "organization type" do
    {
      "501c3/Nonprofit" => [ "501c3/nonprofit", nil ],
      "Non-Profit Organization" => [ "501c3/nonprofit", nil ],
      "501c3/Nonprofit Government Agency" => [ "501c3/nonprofit", nil ],
      "For-Profit" => [ "For-profit", nil ],
      "LLC" => [ "For-profit", nil ],
      "County Government Agency" => [ "Government agency", nil ],
      "Govt agency" => [ "Government agency", nil ],
      "Other" => [ "Other", nil ],
      "School" => [ "Other", "School" ]
    }.each do |fm_type, (type, other)|
      it "reads #{fm_type.inspect} as #{type}#{" (#{other})" if other}" do
        fm_organization("ORG00001", OrgType: fm_type)

        import

        expect(Organization.sole).to have_attributes(organization_type: type, organization_type_other: other)
      end
    end

    it "takes the organization's type over its single project's" do
      fm_organization("ORG00001", OrgType: "Government Agency")
      project("P0001", "ORG00001", AgencyType: "School")

      import

      expect(Organization.sole).to have_attributes(organization_type: "Government agency", organization_type_other: nil)
    end

    it "leaves the description off when the portal's type isn't Other" do
      existing = create(:organization, filemaker_code: "ORG00001", organization_type: "For-profit")
      fm_organization("ORG00001", OrgType: "School")

      import

      expect(existing.reload).to have_attributes(organization_type: "For-profit", organization_type_other: nil)
    end
  end

  describe "phones" do
    def address(fm_id, street)
      FmAddress.create!(fm_id:, data: { "OrgID" => "ORG00001", "AddrsLine1" => street, "AddrsCity" => "Pasadena", "AddrsState" => "CA" })
    end

    it "puts each number on an address with no phone yet, the primary first" do
      fm_organization("ORG00001")
      address("1", "1 Main St")
      address("2", "2 Main St")
      FmPhoneNumber.create!(fm_id: "10", data: { "OrgID" => "ORG00001", "PhoneNumber" => "555-0101", "Primacy" => "1" })
      FmPhoneNumber.create!(fm_id: "11", data: { "OrgID" => "ORG00001", "PhoneNumber" => "555-0102" })

      import

      expect(Organization.sole.addresses.order(:id).pluck(:street_address, :phone))
        .to eq([ [ "1 Main St", "555-0101" ], [ "2 Main St", "555-0102" ] ])
    end

    it "notes a number no address is free to hold, keeping the ones on file" do
      existing = create(:organization, filemaker_code: "ORG00001")
      create(:address, addressable: existing, street_address: "1 Main St", city: "Pasadena", state: "CA", phone: "555-0100")
      fm_organization("ORG00001")
      FmPhoneNumber.create!(fm_id: "10", data: { "OrgID" => "ORG00001", "PhoneNumber" => "555-0199" })

      import = described_class.new.call

      expect(existing.addresses.sole.phone).to eq("555-0100")
      expect(existing.comments.sole.body).to include("Phone", "555-0100", "555-0199")
      expect(import.differences.sole).to include("555-0199")
    end
  end

  it "nests each of an organization's several projects under it" do
    fm_organization("ORG00002", OrgName: "Valley Services")
    project("P0002", "ORG00002", ProjectName: "Valley Adult Program", City: "Fresno", State: "CA", Locality: "Central CA")
    project("P0003", "ORG00002", ProjectName: "Valley Youth Program")

    expect(import.results[:created].size).to eq(3)

    umbrella = Organization.find_by!(name: "Valley Services")
    expect(umbrella.filemaker_code).to eq("ORG00002")
    expect(umbrella.children.pluck(:name, :filemaker_code)).to contain_exactly([ "Valley Adult Program", "P0002" ],
                                                                                [ "Valley Youth Program", "P0003" ])
    expect(Organization.find_by!(name: "Valley Adult Program").addresses.sole)
      .to have_attributes(street_address: "", city: "Fresno", locality: "Central CA")
  end

  it "fills an organization already carrying the code, keeping and noting what it holds" do
    existing = create(:organization, name: "Harbor House Inc", filemaker_code: "P0001", website_url: "old.example.org")
    fm_organization("ORG00001", Website: "harbor.example.org", Mission: "Shelter for all")
    project("P0001", "ORG00001")

    import = described_class.new.call

    expect(import.results[:linked].size).to eq(1)
    expect(existing.reload).to have_attributes(name: "Harbor House Inc", filemaker_code: "ORG00001, P0001",
                                               website_url: "old.example.org", mission_vision_values: "Shelter for all")
    expect(existing.comments.sole.body).to include("ORG00001", "old.example.org", "harbor.example.org")
    expect(import.differences.sole).to include("##{existing.id}")
  end

  it "matches by exact name only an organization with no code from the same table" do
    taken = create(:organization, name: "Harbor House Art Program", filemaker_code: "P0009")
    project("P0009", nil, ProjectName: "Somewhere else")
    fm_organization("ORG00001", OrgName: "Harbor House")
    project("P0001", "ORG00001", ProjectName: "Harbor House Art Program")
    project("P0004", "ORG00001", ProjectName: "Harbor House Youth")

    import

    expect(taken.reload.filemaker_code).to eq("P0009")
    expect(Organization.find_by!(name: "Harbor House Art Program (P0001)").parent.name).to eq("Harbor House")
  end

  it "still brings in the projects of a nameless organization, unnested" do
    fm_organization("ORG00003", OrgName: "")
    project("P0006", "ORG00003", ProjectName: "Lone Program")

    expect(import.results[:skipped].sole).to include("ORG00003", "no name")
    expect(Organization.sole).to have_attributes(name: "Lone Program", filemaker_code: "P0006", parent_id: nil)
  end

  it "folds a merged-away project's code into the program it merged into" do
    fm_organization("ORG00001")
    project("P0001", "ORG00001")
    project("P0005", "ORG00001", ProjectName: "Old Harbor Program", MergerWithID: "P0001")

    results = import.results

    expect(results[:linked].sole).to include("P0005", "merged into P0001")
    expect(Organization.sole.filemaker_code).to eq("ORG00001, P0001, P0005")
  end

  it "reads an agency's own Rolodex card onto its organization" do
    fm_organization("ORG00001")
    FmAddress.create!(fm_id: "7", data: { "RolodexID" => "00090", "AddrsLine1" => "9 Elm St", "AddrsCity" => "Ojai",
                                          "AddrsState" => "CA", "AddrsType" => "Home" })
    FmRolodex.create!(fm_id: "00090", data: { "isAgency__c" => "1", "OrgID" => "ORG00001", "Organization" => "Harbor House",
                                              "WebSite" => "harbor.example.org", "EMail" => "front@harbor.example.org",
                                              "FirstName" => "Ada", "LastName" => "Lovelace" })
    FmRolodex.create!(fm_id: "00091", data: { "isAgency__c" => "1", "Organization" => "Elm Street Clinic",
                                              "EMail" => "hello@elm.example.org" })

    import

    harbor = Organization.find_by!(filemaker_code: "ORG00001")
    expect(harbor).to have_attributes(website_url: "harbor.example.org", email: nil)
    expect(harbor.addresses.sole).to have_attributes(street_address: "9 Elm St", address_type: "work")
    expect(Organization.find_by!(name: "Elm Street Clinic")).to have_attributes(email: "hello@elm.example.org", filemaker_code: nil)
  end

  it "changes nothing when it runs again" do
    fm_organization("ORG00002", OrgName: "Valley Services")
    project("P0002", "ORG00002", ProjectName: "Valley Adult Program", City: "Fresno", State: "CA")
    project("P0003", "ORG00002", ProjectName: "Valley Youth Program")
    FmAddress.create!(fm_id: "1", data: { "OrgID" => "ORG00002", "AddrsLine1" => "1 Main St", "AddrsCity" => "Fresno", "AddrsState" => "CA" })
    import

    expect { expect(import.results[:already_imported].size).to eq(3) }
      .not_to change { [ Organization.count, Address.count, Comment.count ] }
  end
end
