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
    FmPersonnel.create!(fm_id: "PS0001", data: { "PersonID" => "00200", "ProjectID" => "P0001", "Role" => "Leader", "Status" => "Active" })
  end

  def run_task(dry_run: true, task: "fm:import_organizations", run: nil, fm_ids: nil)
    ENV["DRY_RUN"] = dry_run ? "true" : "false"
    ENV["RUN"] = run
    ENV["FM_IDS"] = fm_ids
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
    ENV.delete("FM_IDS")
  end

  it "stops before reading a row when no import user is chosen" do
    expect { run_task(dry_run: false) }.to raise_error(/aborted: No import user chosen/)
    expect(Organization.count).to eq(0)
  end

  it "stops before reading a row when no staff alias is recorded" do
    Setting.create!(import_user: create(:user))

    expect { run_task(dry_run: false) }.to raise_error(/aborted: No staff aliases recorded/)
    expect(Organization.count).to eq(0)
  end

  context "with an import user chosen" do
    before do
      Setting.create!(import_user: create(:user))
      create(:staff_alias)
    end

    it "rolls a dry run back and saves its report" do
      expect { run_task }.to change(ActiveStorage::Blob, :count).by(1)

      expect(Organization.count).to eq(0)
      expect(ActiveStorage::Blob.last.download).to include("People named on agency cards", "Organizations and projects", "DRY RUN")
      expect(ActiveStorage::Blob.last.download).not_to include("Affiliations and work addresses")
    end

    it "reads only the rows FM_IDS names, and says so" do
      FmOrganization.create!(fm_id: "ORG00002", data: { "OrgName" => "Sunrise House" })

      output = run_task(dry_run: false, fm_ids: "ORG00001")

      expect(output).to include("Reading 1 named row(s)", "ORG00001")
      expect(Organization.pluck(:filemaker_code)).to eq([ "ORG00001, P0001" ])
    end

    it "makes the organization, leaving its affiliations to fm:import_affiliations" do
      run_task(dry_run: false)

      expect(Organization.sole.filemaker_code).to eq("ORG00001, P0001")
      expect(person.affiliations).to be_empty
    end

    it "turns an agency card into an organization with its work address" do
      FmAddress.create!(fm_id: "9", data: { "RolodexID" => "00300", "AddrsLine1" => "9 Elm St", "AddrsCity" => "Ojai",
                                            "AddrsState" => "CA", "AddrsType" => "Home" })
      FmRolodex.create!(fm_id: "00300", data: { "isAgency__c" => "1", "Organization" => "Elm Street Clinic", "Title" => "Director" })

      run_task(dry_run: false)

      expect(Organization.find_by!(name: "Elm Street Clinic").addresses.sole).to have_attributes(street_address: "9 Elm St", address_type: "work")
    end

    it "brings in the person an agency card names, which the people import skipped, without affiliating them" do
      FmRolodex.create!(fm_id: "00301", data: { "isAgency__c" => "1", "Organization" => "Harbor Clinic", "Title" => "Director",
                                                "FirstName" => "Grace", "LastName" => "Hopper", "EMail" => "grace@harbor.example.org" })
      FmRolodex.create!(fm_id: "00302", data: { "FirstName" => "Ada", "LastName" => "Lovelace" })

      run_task(dry_run: false)

      expect(Person.find_by!(filemaker_code: "00301").affiliations).to be_empty
      expect(Person.where(filemaker_code: "00302")).to be_empty
    end

    it "names the run so fm:undo_import can reverse it" do
      FmRolodex.create!(fm_id: "00301", data: { "isAgency__c" => "1", "Organization" => "Harbor Clinic",
                                                "FirstName" => "Grace", "LastName" => "Hopper" })
      run = run_task(dry_run: false)[/ RUN=(fm-import-organizations-\d+)/, 1]

      run_task(task: "fm:undo_import", run:, dry_run: false)

      expect(Organization.count).to eq(0)
      expect(Person.where.not(id: person.id)).to be_empty
    end
  end
end
