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
        organization: program, title: "Facilitator", filemaker_code: "PS0001", primary_contact: true,
        start_date: Date.new(2015, 3, 1), end_date: nil, inactive: false, event_registration_id: nil
      )
    end

    it "ends an Inactive row on its project's close date" do
      close_project("2022-06-30 00:00:00")
      personnel("PS0001", Status: "Inactive", Role: "Assistant")

      import

      expect(person.affiliations.sole).to have_attributes(end_date: Date.new(2022, 6, 30), inactive: true, primary_contact: false)
    end

    it "leaves an Inactive row on an open project ended with no end date" do
      personnel("PS0001", Status: "Inactive")

      import

      expect(person.affiliations.sole).to have_attributes(end_date: nil, inactive: true)
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

  describe "a Facilitator affiliation the portal already holds" do
    it "links an undated, open one to an Active row, filling its start date" do
      existing = create(:affiliation, person:, organization: program, title: "Facilitator", start_date: nil, end_date: nil, primary_contact: false)
      personnel("PS0001")

      expect(import.results[:linked].size).to eq(1)
      expect(existing.reload).to have_attributes(filemaker_code: "PS0001", start_date: Date.new(2015, 3, 1), primary_contact: true)
    end

    it "gives the Active row the link when the person has several rows there" do
      existing = create(:affiliation, person:, organization: program, title: "Facilitator", start_date: nil, end_date: nil)
      personnel("PS0001", Status: "Inactive", DateEntered: "2010-01-04 00:00:00")
      personnel("PS0002", DateEntered: "2018-09-10 00:00:00")

      import

      expect(existing.reload).to have_attributes(filemaker_code: "PS0002", start_date: Date.new(2018, 9, 10))
      expect(person.affiliations.where.not(id: existing.id).sole).to have_attributes(filemaker_code: "PS0001", inactive: true)
    end

    it "leaves an open one alone when FileMaker says the person is Inactive, for staff to review" do
      existing = create(:affiliation, person:, organization: program, title: "Facilitator", start_date: nil, end_date: nil)
      personnel("PS0001", Status: "Inactive")

      result = import

      expect(existing.reload).to have_attributes(filemaker_code: nil, start_date: nil, inactive: false)
      expect(result.skip_reasons).to eq("ended in FileMaker, but the portal's Facilitator affiliation there is open" => 1)
    end

    it "leaves an open one with other dates alone when FileMaker says Active" do
      create(:affiliation, person:, organization: program, title: "Facilitator", start_date: Date.new(2024, 1, 10), end_date: nil)
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
      "a person nobody carries" => [ { PersonID: "99999" }, "person wasn't imported" ],
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
