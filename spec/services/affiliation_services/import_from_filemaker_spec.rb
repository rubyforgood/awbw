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

    it "makes a Liaison a primary-contact Facilitator, noting the role FileMaker gave" do
      personnel("PS0001", Role: "Liaison")

      import = described_class.new.call

      affiliation = person.affiliations.sole
      expect(affiliation).to have_attributes(title: "Facilitator", primary_contact: true, start_date: Date.new(2015, 3, 1))
      expect(affiliation.comments.sole).to have_attributes(topic: "FileMaker import", body: a_string_including("Liaison", "PS0001"))
      expect(import.roles).to eq("Liaison → Facilitator, primary contact" => 1)
      expect(affiliation.comments.sole.body).not_to include("Primary contact turned on")
    end

    it "notes a Leader's role too, but not a blank one" do
      personnel("PS0001")
      personnel("PS0002", Role: "", DateEntered: "1/5/2018")

      import

      expect(Comment.where(commentable: person.affiliations).pluck(:body)).to contain_exactly(a_string_including("Leader", "PS0001"))
    end

    it "makes an Assistant a Facilitator who isn't a primary contact, noting the role" do
      personnel("PS0002", Role: "assistant")

      import = described_class.new.call

      affiliation = person.affiliations.sole
      expect(affiliation).to have_attributes(title: "Facilitator", primary_contact: false, start_date: Date.new(2015, 3, 1))
      expect(affiliation.comments.sole.body).to include("assistant", "PS0002")
      expect(import.roles).to eq("assistant → Facilitator" => 1)
    end

    it "turns on primary contact for a Leader's existing Facilitator row, and says so" do
      existing = create(:affiliation, person:, organization: program, title: "Facilitator", primary_contact: false)
      personnel("PS0001")

      import

      expect(existing.reload).to have_attributes(primary_contact: true, filemaker_code: "PS0001")
      expect(existing.comments.sole.body).to include("Leader", "Primary contact turned on")
    end

    it "leaves an Assistant's existing Facilitator row's primary contact as it is" do
      existing = create(:affiliation, person:, organization: program, title: "Facilitator", primary_contact: true)
      personnel("PS0001", Role: "Assistant")

      import

      expect(existing.reload.primary_contact).to be(true)
      expect(existing.comments.sole.body).not_to include("Primary contact turned on")
    end

    it "makes a primary contact only where FileMaker's role says Leader or Liaison" do
      personnel("PS0001", Role: "Leaders")
      personnel("PS0002", Role: "", DateEntered: "1/5/2018")
      personnel("PS0003", Role: "Something else", DateEntered: "1/5/2017")

      import = described_class.new.call

      expect(person.affiliations.order(:filemaker_code).pluck(:filemaker_code, :title, :primary_contact))
        .to eq([ [ "PS0001", "Facilitator", true ], [ "PS0002", "Facilitator", false ], [ "PS0003", "Facilitator", false ] ])
      expect(import.roles).to eq("Leaders → Facilitator, primary contact" => 1, "(blank) → Facilitator" => 1,
                                 "Something else → Facilitator" => 1)
    end

    describe "matching an existing Facilitator row by its stretch" do
      before { FmProject.find_by!(fm_id: "P0001").update!(data: { "OrgID" => "ORG00001" }) }

      def stint(starts, ends = nil)
        create(:affiliation, person:, organization: program, title: "Facilitator", start_date: starts, end_date: ends)
      end

      it "links the stretch the row falls in and leaves the others alone" do
        stint(Date.new(2020, 1, 1), Date.new(2022, 12, 31))
        middle = stint(Date.new(2024, 1, 1), Date.new(2025, 10, 31))
        stint(Date.new(2026, 2, 1))
        personnel("PS0001", DateEntered: "3/1/2024")

        import

        expect(middle.reload.filemaker_code).to eq("PS0001")
        expect(person.affiliations.where.not(id: middle.id).pluck(:filemaker_code)).to all(be_nil)
        expect(person.affiliations.count).to eq(3)
      end

      it "adds a new stretch when none overlaps" do
        stint(Date.new(2020, 1, 1), Date.new(2022, 12, 31))
        personnel("PS0001", DateEntered: "3/1/2024")

        import

        expect(person.affiliations.order(:start_date).pluck(:start_date, :filemaker_code))
          .to eq([ [ Date.new(2020, 1, 1), nil ], [ Date.new(2024, 3, 1), "PS0001" ] ])
      end

      it "reads an ended row with no end date as the moment it started" do
        stint(Date.new(2014, 1, 1), Date.new(2016, 12, 31))
        later = stint(Date.new(2024, 1, 1))
        personnel("PS0001", DateEntered: "3/1/2015", Status: "Inactive")

        import

        expect(later.reload.filemaker_code).to be_nil
        expect(person.affiliations.find_by(start_date: Date.new(2014, 1, 1)).filemaker_code).to eq("PS0001")
      end

      it "links a row with no dates at all when nothing better fits" do
        undated = stint(nil)
        personnel("PS0001", DateEntered: "3/1/2024")

        import

        expect(undated.reload).to have_attributes(filemaker_code: "PS0001", start_date: Date.new(2024, 3, 1))
      end
    end

    it "links the Facilitator affiliation the person already has there, filling its blank start" do
      existing = create(:affiliation, person:, organization: program, title: "Facilitator", filemaker_code: "P0001", start_date: nil)
      personnel("PS0001")

      expect(import.results[:linked].size).to eq(1)
      expect(existing.reload).to have_attributes(filemaker_code: "P0001, PS0001", start_date: Date.new(2015, 3, 1))
      expect(person.affiliations.count).to eq(1)
    end

    it "links a row the old app titled Liaison instead of adding a Facilitator beside it" do
      existing = create(:affiliation, person:, organization: program, title: "Liaison", primary_contact: true)
      personnel("PS0001", Role: "Liaison")

      import

      expect(person.affiliations.sole).to eq(existing)
      expect(existing.reload.filemaker_code).to eq("PS0001")
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

    describe "a row naming a project but no person" do
      it "puts AWBW Placeholder on an organization nothing else affiliates anyone with" do
        personnel("PS0001", PersonID: "", Role: "")
        personnel("PS0002", PersonID: "", Role: "", DateEntered: "1/5/2018")

        import = described_class.new.call

        placeholder = Person.find_by!(first_name: "AWBW", last_name: "Placeholder")
        affiliation = placeholder.affiliations.sole
        expect(affiliation).to have_attributes(organization: program, title: "Facilitator", primary_contact: false, filemaker_code: "PS0001")
        expect(affiliation.comments.sole.body).to include("PS0001", "names no person")
        expect(import.results[:skipped]).to contain_exactly(a_string_including("PS0002", "already has affiliations"))
      end

      it "leaves an organization that already has affiliations alone, even from a later row" do
        personnel("PS0001", PersonID: "")
        personnel("PS0002")

        import

        expect(Person.where(first_name: "AWBW", last_name: "Placeholder")).to be_empty
        expect(program.affiliations.sole.person).to eq(person)
      end

      it "reuses the placeholder person already in the portal" do
        existing = create(:person, first_name: "AWBW", last_name: "Placeholder", email: nil, user: nil)
        personnel("PS0001", PersonID: "")

        import

        expect(existing.affiliations.count).to eq(1)
      end
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
