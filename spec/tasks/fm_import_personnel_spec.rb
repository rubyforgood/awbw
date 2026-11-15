require "rails_helper"
require "rake"

RSpec.describe "fm:import_personnel" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("fm:import_personnel")
  end

  after { Current.reset }

  let!(:person) { create(:person, filemaker_code: "00200") }
  let!(:organization) { create(:organization, filemaker_code: "ORG00001, P0001") }

  before do
    FmProject.create!(fm_id: "P0001", data: { "OrgID" => "ORG00001" })
    FmPersonnel.create!(fm_id: "PS0001", data: { "PersonID" => "00200", "ProjectID" => "P0001", "Role" => "Leader",
                                                 "Status" => "Active", "DateEntered" => "2015-03-01 00:00:00" })
    FmPersonnel.create!(fm_id: "PS0002", data: { "PersonID" => "00200", "ProjectID" => "P0404", "Role" => "Leader",
                                                 "Status" => "Active", "DateEntered" => "2016-03-01 00:00:00" })
  end

  def run_task
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    Rake::Task["fm:import_personnel"].reenable
    Rake::Task["fm:import_personnel"].invoke
    output.string
  rescue SystemExit => e
    raise "fm:import_personnel aborted: #{e.message}"
  ensure
    $stdout = original_stdout
  end

  it "stops before reading a row when no import user is chosen" do
    expect { run_task }.to raise_error(/aborted: Choose an import user/)
    expect(Affiliation.count).to eq(0)
  end

  context "with an import user chosen" do
    before { Setting.create!(import_user: create(:user)) }

    it "imports the rows it can and lists the ones it skipped, by reason" do
      output = run_task

      expect(person.affiliations.sole).to have_attributes(organization:, title: "Facilitator", filemaker_code: "PS0001")
      expect(output).to include("Created", "no org carries the project code", "PS0002")
    end

    it "saves the report it printed" do
      expect { run_task }.to change(ActiveStorage::Blob, :count).by(1)

      expect(ActiveStorage::Blob.last.download).to include("== Result ==", "Skipped, by reason")
    end

    it "logs its activity under the run's source" do
      run_task

      expect(Current.source).to eq("fm_import_personnel")
    end
  end
end
