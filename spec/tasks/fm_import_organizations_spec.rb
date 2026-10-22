require "rails_helper"
require "rake"

RSpec.describe "fm:import_organizations" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("fm:import_organizations")
  end

  after { Current.reset }

  let!(:person) { create(:person, filemaker_code: "00200") }

  before do
    FmOrganization.create!(fm_id: "ORG00001", data: { "OrgName" => "Harbor House" })
    FmProject.create!(fm_id: "P0001", data: { "OrgID" => "ORG00001", "ProjectName" => "Harbor House Art Program" })
    FmPersonnel.create!(fm_id: "PS0001", data: { "PersonID" => "00200", "ProjectID" => "P0001", "Role" => "Facilitator", "Status" => "Active" })
  end

  def run_task(dry_run: true, task: "fm:import_organizations", run: nil)
    ENV["DRY_RUN"] = dry_run ? "true" : "false"
    ENV["RUN"] = run
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    Rake::Task[task].reenable
    Rake::Task[task].prerequisite_tasks.each(&:reenable)
    Rake::Task[task].invoke
    output.string
  rescue SystemExit => e
    raise "#{task} aborted: #{e.message}"
  ensure
    $stdout = original_stdout
    ENV.delete("DRY_RUN")
    ENV.delete("RUN")
  end

  it "stops before reading a row when no import user is chosen" do
    expect { run_task(dry_run: false) }.to raise_error(/aborted: No import user chosen/)
    expect(Organization.count).to eq(0)
  end

  context "with an import user chosen" do
    before { Setting.create!(import_user: create(:user)) }

    it "rolls a dry run back and saves its report" do
      expect { run_task }.to change(ActiveStorage::Blob, :count).by(1)

      expect(Organization.count).to eq(0)
      expect(ActiveStorage::Blob.last.download).to include("Organizations and projects", "Affiliations and work addresses", "DRY RUN")
    end

    it "makes the organization, then the affiliation, on a real run" do
      run_task(dry_run: false)

      organization = Organization.sole
      expect(organization.filemaker_code).to eq("ORG00001, P0001")
      expect(person.affiliations.sole).to have_attributes(organization:, title: "Facilitator", filemaker_code: "PS0001")
    end

    it "names the run so fm:undo_import can reverse it" do
      run = run_task(dry_run: false)[/ RUN=(fm-import-organizations-\d+)/, 1]

      run_task(task: "fm:undo_import", run:, dry_run: false)

      expect(Organization.count).to eq(0)
      expect(Affiliation.count).to eq(0)
    end
  end
end
