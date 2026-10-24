# frozen_string_literal: true

require "rails_helper"

RSpec.describe AffiliationServices::ImportFromFilemaker do
  let!(:person) { create(:person, filemaker_code: "00006") }
  let!(:program) { create(:organization, filemaker_code: "P0001") }
  let!(:umbrella) { create(:organization, filemaker_code: "ORG00001") }

  before { FmProject.create!(fm_id: "P0001", data: { "OrgID" => "ORG00001", "CloseDate" => "6/30/2019" }) }

  def personnel(fm_id, **data)
    FmPersonnel.create!(fm_id:, data: { "PersonID" => "00006", "ProjectID" => "P0001", "Role" => "Leader",
                                        "Status" => "Active", "DateEntered" => "3/1/2015" }.merge(data.stringify_keys))
  end

  def rolodex(**data)
    FmRolodex.create!(fm_id: "00006", data: { "FirstName" => "Ada", "LastName" => "Lovelace" }.merge(data.stringify_keys))
  end

  def import
    described_class.new.call
  end

  describe "personnel" do
    it "makes a Leader a primary-contact Facilitator dated from entry to the project's close" do
      personnel("PS0001")

      expect(import.results[:created].size).to eq(1)
      expect(person.affiliations.sole).to have_attributes(organization: program, title: "Facilitator", filemaker_code: "PS0001", primary_contact: true,
                                                          start_date: Date.new(2015, 3, 1), end_date: Date.new(2019, 6, 30),
                                                          event_registration_id: nil)
    end

    it "ends an assignment whose status isn't active, and tallies the statuses it read" do
      FmProject.find_by!(fm_id: "P0001").update!(data: { "OrgID" => "ORG00001" })
      personnel("PS0001", Status: "Dropped")

      import = described_class.new.call

      expect(person.affiliations.sole).to have_attributes(end_date: nil, inactive: true)
      expect(import.statuses).to eq("Dropped → ended" => 1)
    end

    it "gives a Liaison or Assistant their role plus a Facilitator affiliation over the same dates" do
      personnel("PS0001", Role: "Liaison")
      personnel("PS0002", Role: "assistant", DateEntered: "1/5/2018")

      import = described_class.new.call

      expect(person.affiliations.order(:start_date, :title).pluck(:filemaker_code, :title, :start_date, :primary_contact))
        .to eq([ [ "PS0001", "Facilitator", Date.new(2015, 3, 1), false ], [ "PS0001", "Liaison", Date.new(2015, 3, 1), true ],
                 [ "PS0002", "Assistant", Date.new(2018, 1, 5), false ], [ "PS0002", "Facilitator", Date.new(2018, 1, 5), false ] ])
      expect(import.roles).to eq("Liaison → Liaison" => 1, "assistant → Assistant" => 1)
    end

    it "adds no second Facilitator when one with the same dates is already there" do
      create(:affiliation, person:, organization: program, title: "Facilitator", start_date: Date.new(2015, 3, 1), end_date: Date.new(2019, 6, 30))
      personnel("PS0001", Role: "Liaison")

      import

      expect(person.affiliations.pluck(:title)).to contain_exactly("Facilitator", "Liaison")
    end

    it "reads a blank or unrecognized role as a Leader" do
      personnel("PS0001", Role: "Leaders")
      personnel("PS0002", Role: "", DateEntered: "1/5/2018")

      import = described_class.new.call

      expect(person.affiliations.pluck(:title).uniq).to eq([ "Facilitator" ])
      expect(import.roles).to eq("Leaders → Facilitator" => 1, "(blank) → Facilitator" => 1)
    end

    it "links the Facilitator affiliation the person already has there, filling its blank start" do
      existing = create(:affiliation, person:, organization: program, title: "Facilitator", filemaker_code: "P0001", start_date: nil)
      personnel("PS0001")

      expect(import.results[:linked].size).to eq(1)
      expect(existing.reload).to have_attributes(filemaker_code: "P0001, PS0001", start_date: Date.new(2015, 3, 1))
      expect(person.affiliations.count).to eq(1)
    end

    it "links a row the old app titled Leader instead of adding a Facilitator beside it" do
      existing = create(:affiliation, person:, organization: program, title: "Leader", primary_contact: true)
      personnel("PS0001")

      import

      expect(person.affiliations.sole).to eq(existing)
      expect(existing.reload).to have_attributes(title: "Leader", filemaker_code: "PS0001")
    end

    it "keeps a second stint on the same project as its own affiliation" do
      personnel("PS0001")
      personnel("PS0002", DateEntered: "1/5/2018")

      import

      expect(person.affiliations.pluck(:filemaker_code)).to contain_exactly("PS0001", "PS0002")
    end

    it "skips a row whose person or project wasn't imported" do
      personnel("PS0001", PersonID: "99999")
      personnel("PS0002", ProjectID: "P9999")

      expect(import.results[:skipped]).to contain_exactly(a_string_including("PS0001", "99999"), a_string_including("PS0002", "P9999"))
      expect(Affiliation.count).to eq(0)
    end
  end

  it "makes a job affiliation from a people-to-organizations row" do
    FmPeopleToOrganization.create!(fm_id: "12", data: { "PersonID" => "00006", "OrgID" => "ORG00001", "Title" => "Board Chair" })

    import

    expect(person.affiliations.sole).to have_attributes(organization: umbrella, title: "Board Chair", filemaker_code: "12", start_date: nil)
  end

  describe "the Rolodex card" do
    it "affiliates the person with their organization and points them at its worksite" do
      FmAddress.create!(fm_id: "40", data: { "RolodexID" => "00006", "AddrsLine1" => "1 Main St", "AddrsCity" => "Pasadena", "AddrsState" => "CA" })
      FmAddress.create!(fm_id: "41", data: { "RolodexID" => "00006", "AddrsLine1" => "2 Home Rd", "AddrsCity" => "Pasadena", "AddrsState" => "CA",
                                             "AddrsType" => "Home" })
      rolodex(OrgID: "ORG00001", Title: "Counselor", WorksiteAddrsID: "40", PrimaryAddrsID: "41")

      import

      affiliation = person.affiliations.sole
      expect(affiliation).to have_attributes(organization: umbrella, title: "Counselor", filemaker_code: nil)
      expect(affiliation.organization_address).to have_attributes(addressable: umbrella, street_address: "1 Main St", address_type: "work")
      expect(person.addresses).to be_empty
    end

    it "places a work address on the person's only organization when the card names none" do
      create(:affiliation, person:, organization: program, title: "Facilitator")
      FmAddress.create!(fm_id: "40", data: { "RolodexID" => "00006", "AddrsLine1" => "1 Main St", "AddrsCity" => "Pasadena",
                                             "AddrsState" => "CA", "AddrsType" => "Work" })
      rolodex

      import

      expect(person.affiliations.sole.organization_address).to have_attributes(addressable: program, street_address: "1 Main St")
    end

    it "keeps a work address with the person when no organization can take it" do
      FmAddress.create!(fm_id: "40", data: { "RolodexID" => "00006", "AddrsLine1" => "1 Main St", "AddrsCity" => "Pasadena",
                                             "AddrsState" => "CA", "AddrsType" => "Work" })
      rolodex

      import

      expect(person.addresses.sole).to have_attributes(street_address: "1 Main St", address_type: "work")
    end
  end

  it "changes nothing when it runs again" do
    personnel("PS0001")
    personnel("PS0002", Role: "Liaison")
    FmPeopleToOrganization.create!(fm_id: "12", data: { "PersonID" => "00006", "OrgID" => "ORG00001", "Title" => "Board Chair" })
    FmAddress.create!(fm_id: "40", data: { "RolodexID" => "00006", "AddrsLine1" => "1 Main St", "AddrsCity" => "Pasadena", "AddrsState" => "CA" })
    rolodex(OrgID: "ORG00001", Title: "Counselor", WorksiteAddrsID: "40")
    import

    expect { import }.not_to change { [ Affiliation.count, Address.count, Comment.count, Affiliation.maximum(:updated_at) ] }
  end
end
