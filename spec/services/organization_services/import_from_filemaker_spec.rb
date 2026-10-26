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

  describe "the staff FileMaker stamped on a row" do
    it "reports a staff name no alias answers to, and resolves the ones that do" do
      user = create(:user)
      create(:staff_alias, name: "Dana Whitfield", user:)
      fm_organization("ORG00030", CreatedBy: "Dana Whitfield", ModifiedBy: "Nobody Recorded")

      import = described_class.new.call

      expect(Organization.sole.created_by_id).to eq(user.id)
      expect(import.unmatched_staff).to eq({ "Nobody Recorded" => 1 })
    end
  end

  describe "a project Locality the portal doesn't offer" do
    it "works the locality out from the address instead of storing the archive's word" do
      fm_organization("ORG00050", OrgName: "Shelter")
      project("P0050", "ORG00050", City: "Riverside", State: "CA", County: "Riverside",
                                   Locality: "Riverside County, CA")

      described_class.new.call

      expect(Organization.sole.addresses.sole).to have_attributes(city: "Riverside", locality: "Southern CA")
    end

    it "keeps the archive's word when it is one the portal offers" do
      fm_organization("ORG00051", OrgName: "Haven")
      project("P0051", "ORG00051", City: "Markleeville", State: "CA", County: "Alpine", Locality: "northern ca")

      described_class.new.call

      expect(Organization.sole.addresses.sole.locality).to eq("Northern CA")
    end
  end

  describe "FM_IDS naming the rows to read" do
    before do
      fm_organization("ORG00040", OrgName: "First Org")
      project("P0040", "ORG00040", ProjectName: "First Program")
      fm_organization("ORG00041", OrgName: "Second Org")
      project("P0041", "ORG00041", ProjectName: "Second Program")
    end

    it "reads only the named organization, and brings its project with it" do
      described_class.new(fm_ids: [ "ORG00040" ]).call

      expect(Organization.pluck(:filemaker_code)).to eq([ "ORG00040, P0040" ])
    end

    it "brings a named project's organization in with it" do
      described_class.new(fm_ids: [ "P0041" ]).call

      expect(Organization.pluck(:filemaker_code)).to eq([ "ORG00041, P0041" ])
    end

    it "reads every row when nothing is named" do
      described_class.new.call

      expect(Organization.pluck(:filemaker_code)).to contain_exactly("ORG00040, P0040", "ORG00041, P0041")
    end
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
                                                           address_type: "work", primary: true, filemaker_code: "1",
                                                           locality: "LA County", district: "Foothills",
                                                           la_service_planning_area: 3, la_supervisorial_district: 5)
    expect(organization.contact_methods.sole).to have_attributes(kind: "phone", value: "555-0100", primary: true, filemaker_code: "2")
  end

  it "adds the archive row's code to an address the organization already has" do
    existing = create(:organization, filemaker_code: "ORG00001")
    address = create(:address, addressable: existing, street_address: "1 Main St", city: "Pasadena", state: "CA")
    fm_organization("ORG00001")
    FmAddress.create!(fm_id: "1", data: { "OrgID" => "ORG00001", "AddrsLine1" => "1 Main Street", "AddrsCity" => "Pasadena",
                                          "AddrsState" => "CA" })

    import

    expect(existing.addresses.sole).to eq(address)
    expect(address.reload.filemaker_code).to eq("1")
  end

  it "brings in an address with no street, and makes the one the archive calls postal its invoice address" do
    fm_organization("ORG00001")
    FmAddress.create!(fm_id: "1", data: { "OrgID" => "ORG00001", "AddrsCity" => "Fresno", "AddrsState" => "CA" })
    FmAddress.create!(fm_id: "2", data: { "OrgID" => "ORG00001", "AddrsLine1" => "PO Box 9", "AddrsCity" => "Reno",
                                          "AddrsState" => "NV", "AddrsType" => "Postal" })

    import

    expect(Organization.sole.addresses.order(:filemaker_code).pluck(:street_address, :city, :address_type, :invoice_address))
      .to eq([ [ "", "Fresno", "work", false ], [ "PO Box 9", "Reno", "work", true ] ])
  end

  it "doesn't add a street-less address in a city the organization already has an address in" do
    existing = create(:organization, filemaker_code: "ORG00001")
    address = create(:address, addressable: existing, street_address: "1 Main St", city: "Fresno", state: "CA")
    fm_organization("ORG00001")
    FmAddress.create!(fm_id: "1", data: { "OrgID" => "ORG00001", "AddrsCity" => "Fresno", "AddrsState" => "CA" })

    import

    expect(existing.addresses.sole).to eq(address)
    expect(address.reload.filemaker_code).to eq("1")
  end

  describe "project places" do
    it "reads a project with no state but a California locality as in California" do
      fm_organization("ORG00001")
      project("P0001", "ORG00001", City: "Pasadena", Locality: "LA County", SPA: "3")

      import

      expect(Organization.sole.addresses.sole).to have_attributes(city: "Pasadena", state: "CA", country: "United States",
                                                                  locality: "LA County", la_service_planning_area: 3)
    end

    it "fills a project with no city onto the organization's primary address" do
      fm_organization("ORG00001")
      project("P0001", "ORG00001", State: "CA", County: "Los Angeles", Locality: "LA City", SPA: "4")
      FmAddress.create!(fm_id: "1", data: { "OrgID" => "ORG00001", "AddrsLine1" => "1 Main St", "AddrsCity" => "Los Angeles",
                                            "AddrsState" => "CA" })

      result = import

      expect(Organization.sole.addresses.sole).to have_attributes(street_address: "1 Main St", locality: "LA City",
                                                                  la_service_planning_area: 4)
      expect(result.unplaced).to be_empty
    end

    it "lists a project whose place has no city or state to be saved with" do
      fm_organization("ORG00002", OrgName: "Valley Services")
      project("P0002", "ORG00002", ProjectName: "Tokyo Program", City: "Tokyo", Locality: "Outside USA")
      project("P0003", "ORG00002", ProjectName: "Roaming Program", State: "CA", Locality: "LA City", SPA: "4")
      project("P0004", "ORG00002", ProjectName: "Blank Program")

      result = import

      expect(Organization.find_by!(name: "Tokyo Program").addresses).to be_empty
      expect(result.unplaced).to contain_exactly(
        "P0002 Tokyo Program: Tokyo, no state (Locality Outside USA)",
        "P0003 Roaming Program: no city (Locality LA City, La service planning area 4)"
      )
    end
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
      # Every word the four types can't hold keeps itself as the description, so nothing the
      # archive said is lost: these are the ones production holds.
      "School" => [ "Other", "School" ],
      "Educational Institution" => [ "Other", "Educational Institution" ],
      "Individual" => [ "Other", "Individual" ],
      "Grassroots" => [ "Other", "Grassroots" ]
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
    def phone(fm_id, number, **data)
      FmPhoneNumber.create!(fm_id:, data: { "OrgID" => "ORG00001", "PhoneNumber" => number }.merge(data.stringify_keys))
    end

    it "brings each number in as a phone carrying its code, the primary first" do
      fm_organization("ORG00001")
      phone("11", "555-0102")
      phone("10", "555-0101", Primacy: "1", PhoneType: "Work")

      import

      expect(Organization.sole.contact_methods.order(:id).pluck(:value, :contact_type, :primary, :filemaker_code))
        .to eq([ [ "555-0101", "work", true, "10" ], [ "555-0102", "unknown", false, "11" ] ])
    end

    it "reads FileMaker's Work/Day and Home/Eve phone types" do
      fm_organization("ORG00001")
      phone("10", "555-0101", PhoneType: "Work/Day")
      phone("11", "555-0102", PhoneType: "Home/Eve")

      import

      expect(Organization.sole.contact_methods.order(:filemaker_code).pluck(:contact_type)).to eq(%w[work personal])
    end

    it "lists the phone types it can't read" do
      fm_organization("ORG00001")
      phone("10", "555-0101", PhoneType: "Fax")
      phone("11", "555-0102", PhoneType: "Fax")

      expect(import.unmatched_phone_types).to eq("Fax" => 2)
    end

    it "adds the code to a phone the organization already has, keeping its primary" do
      existing = create(:organization, filemaker_code: "ORG00001")
      held = existing.contact_methods.create!(kind: "phone", value: "(555) 0100", primary: true)
      fm_organization("ORG00001")
      phone("10", "555-0100")
      phone("11", "555-0199", Primacy: "1")

      import

      expect(existing.contact_methods.order(:id).pluck(:value, :primary, :filemaker_code))
        .to eq([ [ "(555) 0100", true, "10" ], [ "555-0199", false, "11" ] ])
      expect(held.reload.filemaker_code).to eq("10")
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

  describe "an organization FileMaker nests under another (ParentID)" do
    it "nests it under its parent's portal organization" do
      fm_organization("ORG00010", OrgName: "Valley Services")
      fm_organization("ORG00011", OrgName: "Valley Services Fresno", ParentID: "ORG00010")

      import = described_class.new.call

      parent = Organization.find_by!(filemaker_code: "ORG00010")
      expect(Organization.find_by!(filemaker_code: "ORG00011").parent_id).to eq(parent.id)
      expect(import.nested.sole).to include("ORG00011", "under ##{parent.id}")
    end

    it "keeps a parent the portal already set, noting FileMaker's" do
      elsewhere = create(:organization)
      child = create(:organization, filemaker_code: "ORG00011", parent: elsewhere)
      fm_organization("ORG00010", OrgName: "Valley Services")
      fm_organization("ORG00011", OrgName: "Valley Services Fresno", ParentID: "ORG00010")

      import = described_class.new.call

      expect(child.reload.parent).to eq(elsewhere)
      expect(import.differences).to include(a_string_including("ORG00011", "kept parent ##{elsewhere.id}"))
    end

    it "leaves an organization alone that is the same portal organization as its parent" do
      both = create(:organization, filemaker_code: "ORG00010, ORG00011")
      fm_organization("ORG00010", OrgName: "Valley Services")
      fm_organization("ORG00011", OrgName: "Valley Services Fresno", ParentID: "ORG00010")

      import = described_class.new.call

      expect(both.reload.parent_id).to be_nil
      expect(import.nested.sole).to include("ORG00011", "same organization as its parent")
    end

    it "notes a parent that wasn't imported" do
      fm_organization("ORG00011", OrgName: "Valley Services Fresno", ParentID: "ORG09999")

      import = described_class.new.call

      expect(Organization.sole.parent_id).to be_nil
      expect(import.nested.sole).to include("ORG00011", "ORG09999", "wasn't imported")
    end
  end

  describe "records retired in FileMaker" do
    before do
      stub_const("FilemakerValues::RETIRED_RECORDS", %w[ORG00007 P0002 P0003])
    end

    describe "a retired duplicate of another organization" do
      before { stub_const("FilemakerValues::RETIRED_DUPLICATE_OF", { "ORG00007" => "ORG00001" }) }

      it "folds into the organization it duplicated: its code, data, and projects" do
        fm_organization("ORG00001")
        fm_organization("ORG00007", OrgName: "Harbor House Do Not Use", Website: "harbor.example.org", Mission: "Shelter for all")
        project("P0007", "ORG00007", ProjectName: "Harbor Teen Program")
        FmAddress.create!(fm_id: "1", data: { "OrgID" => "ORG00007", "AddrsLine1" => "1 Main St", "AddrsCity" => "Pasadena", "AddrsState" => "CA" })
        FmPhoneNumber.create!(fm_id: "2", data: { "OrgID" => "ORG00007", "PhoneNumber" => "555-0100" })

        results = import.results

        original = Organization.find_by!(name: "Harbor House")
        expect(results[:linked]).to include(a_string_including("ORG00007", "##{original.id}", "duplicate of ORG00001"))
        expect(original).to have_attributes(filemaker_code: "ORG00001, ORG00007", website_url: "harbor.example.org",
                                            mission_vision_values: "Shelter for all")
        expect(original.addresses.sole).to have_attributes(street_address: "1 Main St", filemaker_code: "1")
        expect(original.contact_methods.sole).to have_attributes(value: "555-0100", filemaker_code: "2")
        expect(original.children.sole).to have_attributes(name: "Harbor Teen Program", filemaker_code: "P0007")
        expect(Organization.where("name LIKE ?", "%Do Not Use%")).to be_empty
      end

      it "lands an agency card naming the duplicate on the original" do
        fm_organization("ORG00001")
        fm_organization("ORG00007", OrgName: "Harbor House Do Not Use")
        FmRolodex.create!(fm_id: "00091", data: { "isAgency__c" => "1", "OrgID" => "ORG00007", "WebSite" => "harbor.example.org" })

        import

        expect(Organization.sole).to have_attributes(name: "Harbor House", website_url: "harbor.example.org")
      end

      it "is skipped, its projects unnested, when the original wasn't imported" do
        fm_organization("ORG00007", OrgName: "Harbor House Do Not Use")
        project("P0007", "ORG00007", ProjectName: "Harbor Teen Program")

        expect(import.results[:skipped].sole).to include("ORG00007", "ORG00001", "wasn't imported")
        expect(Organization.sole).to have_attributes(name: "Harbor Teen Program", parent_id: nil)
      end
    end

    describe "a retired organization whose namesake is elsewhere" do
      before { stub_const("FilemakerValues::RETIRED_RENAMED", %w[ORG00008]) }

      it "comes in as its own organization, told apart from its namesake by its code" do
        create(:organization, name: "Harbor House")
        fm_organization("ORG00008", OrgName: "Harbor House Do Not Use", Website: "harbor.example.org")

        import

        expect(Organization.find_by!(filemaker_code: "ORG00008")).to have_attributes(name: "Harbor House (ORG00008)", website_url: "harbor.example.org")
      end

      it "names the one organization it makes with its single project the same way" do
        fm_organization("ORG00008", OrgName: "Harbor House Do Not Use")
        project("P0008", "ORG00008", ProjectName: "Harbor Teen Program")

        import

        expect(Organization.sole).to have_attributes(name: "Harbor House (ORG00008)", filemaker_code: "ORG00008, P0008")
      end
    end

    it "leaves out a retired organization, bringing its projects in unnested" do
      fm_organization("ORG00007", OrgName: "Harbor House Do Not Use")
      project("P0007", "ORG00007", ProjectName: "Harbor Teen Program")
      project("P0008", "ORG00007", ProjectName: "Harbor Adult Program")

      expect(import.results[:skipped].sole).to include("ORG00007", "retired")
      expect(Organization.pluck(:name, :parent_id)).to contain_exactly([ "Harbor Teen Program", nil ], [ "Harbor Adult Program", nil ])
    end

    it "leaves out retired projects by code, whatever their name, keeping their organization one place" do
      fm_organization("ORG00001")
      project("P0001", "ORG00001")
      project("P0002", "ORG00001", ProjectName: "DELETE")
      project("P0003", "ORG00001", ProjectName: "Harbor House Program")

      results = import.results

      expect(results[:skipped]).to contain_exactly(a_string_including("P0002", "retired"), a_string_including("P0003", "retired"))
      expect(Organization.sole).to have_attributes(name: "Harbor House", filemaker_code: "ORG00001, P0001")
    end

    it "brings in an unlisted project even when its name says DELETE" do
      fm_organization("ORG00001")
      project("P0004", "ORG00001", ProjectName: "Harbor House Art Program - DELETE")

      import

      expect(Organization.sole.filemaker_code).to eq("ORG00001, P0004")
    end

    it "creates no organization for an agency card naming a retired one" do
      FmRolodex.create!(fm_id: "00091", data: { "isAgency__c" => "1", "OrgID" => "ORG00007", "Organization" => "Harbor House Do Not Use" })

      expect(import.results[:skipped].sole).to include("00091", "retired")
      expect(Organization.count).to eq(0)
    end
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
