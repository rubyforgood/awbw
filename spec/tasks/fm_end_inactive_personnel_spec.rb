require "rails_helper"
require "rake"

RSpec.describe "fm:end_inactive_personnel" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("fm:end_inactive_personnel")
  end

  after { Current.reset }

  let!(:person) { create(:person, filemaker_code: "00200") }
  let!(:organization) { create(:organization, filemaker_code: "ORG00001, P0001") }
  let!(:affiliation) do
    create(:affiliation, person:, organization:, title: "Facilitator", filemaker_code: "PS0001",
                         start_date: Date.new(2015, 3, 1), end_date: nil, inactive: true, inactive_supplied: true)
  end

  before do
    FmPersonnel.create!(fm_id: "PS0001", data: { "PersonID" => "00200", "ProjectID" => "P0001", "Status" => "Inactive",
                                                 "DateEntered" => "2015-03-01 00:00:00" })
  end

  def run_task(dry_run: true)
    ENV["DRY_RUN"] = dry_run ? "true" : "false"
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    Rake::Task["fm:end_inactive_personnel"].reenable
    Rake::Task["fm:end_inactive_personnel"].invoke
    output.string
  ensure
    $stdout = original_stdout
    ENV.delete("DRY_RUN")
  end

  it "rolls a dry run back, reports what it would set, and logs nothing" do
    output = run_task

    expect(affiliation.reload.end_date).to be_nil
    expect(output).to include("DRY RUN", "December 31 of the year they started")
    expect(Ahoy::Event.count).to eq(0)
  end

  it "sets the end dates, saves the report and logs one summary event" do
    run_task(dry_run: false)

    expect(affiliation.reload.end_date).to eq(Date.new(2015, 12, 31))
    summary = Ahoy::Event.sole
    expect(summary).to have_attributes(name: "end_dates.affiliation")
    expect(summary.properties).to include("stand_in" => 1, "report_blob_id" => ActiveStorage::Blob.last.id)
  end
end
