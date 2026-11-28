require "rails_helper"

RSpec.describe AffiliationServices::ImportPersonnel do
  let!(:person) { create(:person, filemaker_code: "00006") }
  let!(:program) { create(:organization, filemaker_code: "ORG00001, P0001") }
  let!(:import_user) { create(:user) }

  before do
    Setting.create!(import_user:)
    FmProject.create!(fm_id: "P0001", data: { "OrgID" => "ORG00001" })
  end

  def personnel(fm_id, **data)
    FmPersonnel.create!(fm_id:, data: { "PersonID" => "00006", "ProjectID" => "P0001", "Role" => "Leader",
                                        "Status" => "Active", "DateEntered" => "2015-03-01 00:00:00" }.merge(data.stringify_keys))
  end

  def close_project(on)
    FmProject.find_by!(fm_id: "P0001").update!(data: { "OrgID" => "ORG00001", "CloseDate" => on })
  end

  def import
    described_class.new.call
  end

  describe "a row with no open question" do
    it "makes an Active Leader an open, primary-contact Facilitator from the day it was entered" do
      personnel("PS0001")

      expect(import.results[:created].size).to eq(1)
      expect(person.affiliations.sole).to have_attributes(
        organization: program, type: "facilitator", filemaker_code: "PS0001", primary_contact: true,
        start_date: Date.new(2015, 3, 1), end_date: nil, inactive: false, event_registration_id: nil
      )
    end

    it "ends an Inactive row on its project's close date" do
      close_project("2022-06-30 00:00:00")
      personnel("PS0001", Status: "Inactive", Role: "Assistant")

      import

      expect(person.affiliations.sole).to have_attributes(end_date: Date.new(2022, 6, 30), inactive: true, primary_contact: false)
    end

    it "ends an Inactive row FileMaker gives no evidence for on December 31 of its start year, and says so" do
      personnel("PS0001", Status: "Inactive")

      import

      affiliation = person.affiliations.sole
      expect(affiliation).to have_attributes(end_date: Date.new(2015, 12, 31), inactive: true)
      expect(affiliation.comments.sole.body).to include("Ends 2015-12-31, from December 31 of the year they started (a stand-in).")
    end

    it "records the role, status and notes FileMaker gave in a comment" do
      personnel("PS0001", Role: "Liaison", Notes: "Runs Tuesday groups")

      import

      expect(person.affiliations.sole.comments.sole).to have_attributes(
        topic: "FileMaker import",
        body: "FileMaker Personnel PS0001 on project P0001: role Liaison, status Active. Notes: \"Runs Tuesday groups\""
      )
    end

    it "credits the staff FileMaker named, else the import user, and keeps FileMaker's dates" do
      staff = create(:user)
      create(:staff_alias, name: "Dana Whitfield", user: staff)
      personnel("PS0001", EnteredBy: "Dana Whitfield", ModifiedBy: "Nobody Recorded", DateTimeModified: "2021-02-05 21:11:53")

      result = import

      expect(person.affiliations.sole).to have_attributes(
        created_by_id: staff.id, updated_by_id: import_user.id,
        created_at: Date.new(2015, 3, 1).in_time_zone, updated_at: Date.new(2021, 2, 5).in_time_zone
      )
      expect(result.unmatched_staff).to eq("Nobody Recorded" => 1)
    end

    it "skips a row already imported on a rerun" do
      personnel("PS0001")
      import

      expect(import.results[:already_imported].size).to eq(1)
      expect(person.affiliations.count).to eq(1)
    end
  end

  describe "activity" do
    after { Current.reset }

    it "logs one create event per new affiliation, dated and credited as FileMaker recorded it, and nothing else" do
      staff = create(:user)
      create(:staff_alias, name: "Dana Whitfield", user: staff)
      personnel("PS0001", EnteredBy: "Dana Whitfield", Notes: "Runs Tuesday groups")

      import

      event = Ahoy::Event.sole
      expect(event).to have_attributes(name: "create.affiliation", user_id: staff.id, time: Date.new(2015, 3, 1).in_time_zone)
      expect(event.properties).to include("resource_id" => person.affiliations.sole.id, "source" => "fm_import_personnel")
    end

    it "logs nothing for an affiliation it links" do
      create(:affiliation, person:, organization: program, type: "facilitator", start_date: nil, end_date: nil)
      personnel("PS0001")

      expect { import }.not_to change(Ahoy::Event, :count)
    end
  end

  describe "the end date of an Inactive row on a project FileMaker never closed" do
    def workshop_log(fm_id, leader:, date:)
      FmWorkshopLog.create!(fm_id:, data: { "LeaderID" => leader, "ProjectID" => "P0001", "WorkshopDate" => date })
    end

    def ends_on
      person.affiliations.sole.end_date
    end

    it "is their own last workshop log on the project first" do
      personnel("PS0001", Status: "Inactive", DateTimeModified: "2021-02-05 21:11:53")
      workshop_log("W1", leader: "00006", date: "2019-11-12")
      workshop_log("W2", leader: "00006", date: "2020-01-28")
      workshop_log("W3", leader: "00999", date: "2022-06-01")

      result = import

      expect(ends_on).to eq(Date.new(2020, 1, 28))
      expect(result.end_sources).to eq(own_log: 1)
    end

    it "is the day the row was last saved first when its notes say they left" do
      personnel("PS0001", Status: "Inactive", Notes: "No longer with organization", DateTimeModified: "2021-02-05 21:11:53")
      workshop_log("W1", leader: "00006", date: "2019-11-12")

      import

      expect(ends_on).to eq(Date.new(2021, 2, 5))
    end

    it "falls back to the project's last workshop log by anyone" do
      personnel("PS0001", Status: "Inactive")
      workshop_log("W1", leader: "00999", date: "2018-04-09")

      import

      expect(ends_on).to eq(Date.new(2018, 4, 9))
    end

    it "skips evidence dated before the row started" do
      personnel("PS0001", Status: "Inactive")
      workshop_log("W1", leader: "00006", date: "2014-06-01")

      import

      expect(ends_on).to eq(Date.new(2015, 12, 31))
    end

    it "is the latest dated entry in their notes saying they stopped, ahead of every other clue" do
      close_project("2022-06-30 00:00:00")
      personnel("PS0001", Status: "Inactive", DateEntered: "2008-03-01 00:00:00",
                          Notes: "6/24/2013: No longer at the agency. Removed permissions. 10/15/2012: Now children's leader. Activated.")

      result = import

      expect(ends_on).to eq(Date.new(2013, 6, 24))
      expect(result.end_sources).to eq(notes: 1)
    end

    it "reads a month and year in their notes as the 1st of that month" do
      personnel("PS0001", Status: "Inactive", DateEntered: "2008-03-01 00:00:00", Notes: "no longer at program 01/2011")

      import

      expect(ends_on).to eq(Date.new(2011, 1, 1))
    end

    it "ignores an entry that's about starting" do
      personnel("PS0001", Status: "Inactive", Notes: "3/12/2013: Now children's leader. Activated and gave permissions.")

      import

      expect(ends_on).to eq(Date.new(2015, 12, 31))
    end

    it "ends on the start date when their notes say the program never started" do
      personnel("PS0001", Status: "Inactive", Notes: "7/10/2015: Program never started. Removed permissions.")

      result = import

      expect(person.affiliations.sole).to have_attributes(start_date: Date.new(2015, 3, 1), end_date: Date.new(2015, 3, 1))
      expect(result.end_sources).to eq(never_started: 1)
    end

    it "is never later than yesterday" do
      personnel("PS0001", Status: "Inactive", DateEntered: 3.days.ago.to_date.iso8601)

      import

      expect(ends_on).to eq(Date.yesterday)
    end
  end

  describe "a Facilitator affiliation the portal already holds" do
    it "links an undated, open one to an Active row, filling its start date" do
      existing = create(:affiliation, person:, organization: program, type: "facilitator", start_date: nil, end_date: nil, primary_contact: false)
      personnel("PS0001")

      expect(import.results[:linked].size).to eq(1)
      expect(existing.reload).to have_attributes(filemaker_code: "PS0001", start_date: Date.new(2015, 3, 1), primary_contact: true)
    end

    it "gives the Active row the link when the person has several rows there" do
      existing = create(:affiliation, person:, organization: program, type: "facilitator", start_date: nil, end_date: nil)
      personnel("PS0001", Status: "Inactive", DateEntered: "2010-01-04 00:00:00")
      personnel("PS0002", DateEntered: "2018-09-10 00:00:00")

      import

      expect(existing.reload).to have_attributes(filemaker_code: "PS0002", start_date: Date.new(2018, 9, 10))
      expect(person.affiliations.where.not(id: existing.id).sole).to have_attributes(filemaker_code: "PS0001", inactive: true)
    end

    it "leaves an open one alone when FileMaker says the person is Inactive, for staff to review" do
      existing = create(:affiliation, person:, organization: program, type: "facilitator", start_date: nil, end_date: nil)
      personnel("PS0001", Status: "Inactive")

      result = import

      expect(existing.reload).to have_attributes(filemaker_code: nil, start_date: nil, inactive: false)
      expect(result.skip_reasons).to eq("ended in FileMaker, but the portal's Facilitator affiliation there is open" => 1)
    end

    it "links an Active row to a current one starting within 90 days, keeping its training dates" do
      training_row = create(:affiliation, person:, organization: program, type: "facilitator",
                                          start_date: Date.new(2015, 3, 20), end_date: nil, primary_contact: false)
      personnel("PS0001")

      expect(import.results[:linked].size).to eq(1)
      expect(training_row.reload).to have_attributes(filemaker_code: "PS0001", start_date: Date.new(2015, 3, 20), primary_contact: true)
      expect(training_row.comments.sole.body).to include("FileMaker entered them on 2015-03-01; this affiliation keeps its own start date.")
    end

    it "leaves an open one with other dates alone when FileMaker says Active" do
      create(:affiliation, person:, organization: program, type: "facilitator", start_date: Date.new(2024, 1, 10), end_date: nil)
      personnel("PS0001")

      result = import

      expect(person.affiliations.count).to eq(1)
      expect(result.skip_reasons.keys).to eq([ "Active in FileMaker, and the portal has an open Facilitator affiliation there with other dates" ])
    end

    it "folds two rows that would make the same affiliation into one carrying both codes" do
      personnel("PS0001", Status: "Inactive")
      personnel("PS0002", Status: "Inactive")

      result = import

      expect(person.affiliations.sole.filemaker_codes).to contain_exactly("PS0001", "PS0002")
      expect(result.results[:merged].size).to eq(1)
    end
  end

  describe "a row with an open question" do
    {
      "a status that's neither Active nor Inactive" => [ { Status: "ActiveInactive" }, "status is neither Active nor Inactive" ],
      "a blank start date" => [ { DateEntered: "" }, "no readable start date" ],
      "a start date before 1990" => [ { DateEntered: "10/23/0209" }, "start date before 1990" ],
      "a person with no Rolodex card in the archive" => [ { PersonID: "99999" }, "no Rolodex card for the person in the FileMaker archive" ],
      "no project" => [ { ProjectID: "" }, "names no project" ],
      "a project no org carries" => [ { ProjectID: "P0404" }, "no org carries the project code" ]
    }.each do |description, (data, reason)|
      it "skips #{description} and reports why" do
        personnel("PS0001", **data)

        result = import

        expect(person.affiliations).to be_empty
        expect(result.skip_reasons).to eq(reason => 1)
      end
    end

    it "skips a person whose Rolodex card the people import never brought in" do
      FmRolodex.create!(fm_id: "00888", data: { "FirstName" => "Ada", "LastName" => "Lovelace" })
      personnel("PS0001", PersonID: "00888")

      expect(import.skip_reasons).to eq("person wasn't imported" => 1)
    end

    it "skips a row naming an agency card, which is an organization, not a person" do
      FmRolodex.create!(fm_id: "00777", data: { "isAgency__c" => "1", "Organization" => "Harbor House" })
      personnel("PS0001", PersonID: "00777")

      expect(import.skip_reasons).to eq("names an agency card, not a person" => 1)
    end

    it "skips a project whose code is on several orgs" do
      create(:organization, filemaker_code: "P0001")
      personnel("PS0001")

      expect(import.skip_reasons).to eq("project code is on several orgs" => 1)
    end

    it "skips an Active row on a closed project" do
      close_project("2023-01-31 00:00:00")
      personnel("PS0001")

      expect(import.skip_reasons).to eq("Active in FileMaker, but its project is closed" => 1)
    end
  end
end
