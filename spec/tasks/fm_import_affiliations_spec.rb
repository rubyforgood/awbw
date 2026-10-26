require "rails_helper"
require "rake"

RSpec.describe "fm:import_affiliations" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("fm:import_affiliations")
  end

  after { Current.reset }

  let!(:person) { create(:person, filemaker_code: "00200") }
  let!(:organization) { create(:organization, name: "Harbor House", filemaker_code: "ORG00001, P0001") }

  before do
    FmOrganization.create!(fm_id: "ORG00001", data: { "OrgName" => "Harbor House" })
    FmProject.create!(fm_id: "P0001", data: { "OrgID" => "ORG00001", "ProjectName" => "Harbor House Art Program" })
    FmPersonnel.create!(fm_id: "PS0001", data: { "PersonID" => "00200", "ProjectID" => "P0001", "Role" => "Leader", "Status" => "Active" })
  end

  def run_task(dry_run: true, task: "fm:import_affiliations", run: nil, fm_ids: nil)
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
    expect(Affiliation.count).to eq(0)
  end

  context "with an import user chosen" do
    before do
      Setting.create!(import_user: create(:user))
      create(:staff_alias)
    end

    it "rolls a dry run back and saves its report" do
      expect { run_task }.to change(ActiveStorage::Blob, :count).by(1)

      expect(Affiliation.count).to eq(0)
      expect(ActiveStorage::Blob.last.download).to include("Affiliations and work addresses", "DRY RUN")
    end

    it "affiliates the person with the organization the organizations import made" do
      run_task(dry_run: false)

      expect(person.affiliations.sole).to have_attributes(organization:, title: "Facilitator", filemaker_code: "PS0001")
    end

    it "reads only the rows FM_IDS names" do
      FmPersonnel.create!(fm_id: "PS0002", data: { "PersonID" => "00200", "ProjectID" => "P0001", "Role" => "Leader",
                                                   "Status" => "Active", "DateEntered" => "1/1/2020" })

      output = run_task(dry_run: false, fm_ids: "PS0001")

      expect(output).to include("Reading 1 named row(s)", "PS0001")
      expect(person.affiliations.pluck(:filemaker_code)).to eq([ "PS0001" ])
    end

    it "affiliates the person an agency card names with its agency, at the work address the organizations import placed" do
      FmAddress.create!(fm_id: "9", data: { "RolodexID" => "00300", "AddrsLine1" => "9 Elm St", "AddrsCity" => "Ojai",
                                            "AddrsState" => "CA", "AddrsType" => "Home" })
      FmRolodex.create!(fm_id: "00300", data: { "isAgency__c" => "1", "Organization" => "Elm Street Clinic", "Title" => "Director",
                                                "FirstName" => "Ada", "LastName" => "Lovelace" })

      run_task(task: "fm:import_organizations", dry_run: false)
      run_task(dry_run: false)

      clinic = Organization.find_by!(name: "Elm Street Clinic")
      contact = Person.find_by!(filemaker_code: "00300")
      expect(contact.affiliations.sole).to have_attributes(organization: clinic, title: "Director", organization_address: clinic.addresses.sole)
      expect(contact.addresses).to be_empty
    end

    it "affiliates someone staffing an unimported project with the organization their card names, which undoing leaves" do
      FmPersonnel.create!(fm_id: "PS0002", data: { "PersonID" => "00200", "ProjectID" => "", "Status" => "Active" })
      FmRolodex.create!(fm_id: "00200", data: { "FirstName" => "Ada", "LastName" => "Lovelace", "Organization" => "Foothill Family Services" })

      run_task(task: "fm:import_organizations", dry_run: false)
      foothill = Organization.find_by!(name: "Foothill Family Services")
      run = run_task(dry_run: false)[/ RUN=(fm-import-affiliations-\d+)/, 1]

      expect(person.affiliations.find_by!(filemaker_code: "PS0002").organization).to eq(foothill)

      run_task(task: "fm:undo_import", run:, dry_run: false)

      expect(Organization.where(id: foothill.id)).to exist
    end

    it "names the run so fm:undo_import can reverse it, leaving the organizations" do
      run = run_task(dry_run: false)[/ RUN=(fm-import-affiliations-\d+)/, 1]

      run_task(task: "fm:undo_import", run:, dry_run: false)

      expect(Affiliation.count).to eq(0)
      expect(Organization.all).to eq([ organization ])
    end
  end
end
