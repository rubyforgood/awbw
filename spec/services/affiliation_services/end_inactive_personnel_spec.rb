require "rails_helper"

RSpec.describe AffiliationServices::EndInactivePersonnel do
  let!(:person) { create(:person, filemaker_code: "00006") }
  let!(:program) { create(:organization, filemaker_code: "ORG00001, P0001") }

  after { Current.reset }

  def personnel(fm_id, **data)
    FmPersonnel.create!(fm_id:, data: { "PersonID" => "00006", "ProjectID" => "P0001", "Status" => "Inactive",
                                        "DateEntered" => "2015-03-01 00:00:00" }.merge(data.stringify_keys))
  end

  def ended(code = "PS0001", start_date: Date.new(2015, 3, 1))
    create(:affiliation, person:, organization: program, title: "Facilitator", filemaker_code: code,
                         start_date:, end_date: nil, inactive: true, inactive_supplied: true)
  end

  def workshop_log(fm_id, leader:, date:)
    FmWorkshopLog.create!(fm_id:, data: { "LeaderID" => leader, "ProjectID" => "P0001", "WorkshopDate" => date })
  end

  def run
    described_class.new.call
  end

  it "ends on their own last workshop log on the project first" do
    personnel("PS0001", DateTimeModified: "2021-02-05 21:11:53")
    workshop_log("W1", leader: "00006", date: "2019-11-12")
    workshop_log("W2", leader: "00006", date: "2020-01-28")
    workshop_log("W3", leader: "00999", date: "2022-06-01")
    affiliation = ended

    expect(run.results[:own_log].size).to eq(1)
    expect(affiliation.reload).to have_attributes(end_date: Date.new(2020, 1, 28), inactive: true)
    expect(affiliation.comments.sole.body).to include("2020-01-28", "their own last workshop log")
  end

  it "uses the day the row was last saved first when its notes say they left" do
    personnel("PS0001", Notes: "No longer with organization", DateTimeModified: "2021-02-05 21:11:53")
    workshop_log("W1", leader: "00006", date: "2019-11-12")
    affiliation = ended

    run

    expect(affiliation.reload.end_date).to eq(Date.new(2021, 2, 5))
  end

  it "falls back to the project's last workshop log by anyone" do
    personnel("PS0001")
    workshop_log("W1", leader: "00999", date: "2018-04-09")
    affiliation = ended

    expect(run.results[:project_log].size).to eq(1)
    expect(affiliation.reload.end_date).to eq(Date.new(2018, 4, 9))
  end

  it "ends on December 31 of the start year when FileMaker gives no evidence" do
    personnel("PS0001")
    affiliation = ended

    expect(run.results[:stand_in].size).to eq(1)
    expect(affiliation.reload.end_date).to eq(Date.new(2015, 12, 31))
    expect(affiliation.comments.sole.body).to include("(a stand-in)")
  end

  it "skips evidence dated before the row started" do
    personnel("PS0001")
    workshop_log("W1", leader: "00006", date: "2014-06-01")
    affiliation = ended

    run

    expect(affiliation.reload.end_date).to eq(Date.new(2015, 12, 31))
  end

  it "never sets an end date after yesterday" do
    personnel("PS0001", DateEntered: Date.current.iso8601)
    affiliation = ended(start_date: 3.days.ago.to_date)

    run

    expect(affiliation.reload.end_date).to eq(Date.yesterday)
  end

  it "leaves open, already-dated and hand-entered affiliations alone" do
    personnel("PS0001")
    open_row = create(:affiliation, person:, organization: program, title: "Facilitator", filemaker_code: "PS0001",
                                    start_date: Date.new(2015, 3, 1), end_date: nil)
    dated = ended("PS0002").tap { |row| row.update!(end_date: Date.new(2016, 1, 1)) }
    hand_entered = ended(nil)

    expect { run }.not_to change { [ open_row.reload.end_date, dated.reload.end_date, hand_entered.reload.end_date ] }
  end

  it "writes no activity events of its own" do
    personnel("PS0001")
    ended

    expect { run }.not_to change(Ahoy::Event, :count)
  end
end
