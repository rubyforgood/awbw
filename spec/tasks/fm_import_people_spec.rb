require "rails_helper"
require "rake"

RSpec.describe "fm:import_people" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("fm:import_people")
  end

  after { Current.reset }

  before do
    FmRolodex.create!(fm_id: "00200", data: { "FirstName" => "Ada", "LastName" => "Lovelace", "EMail" => "ada@example.com" })
  end

  def run_task(dry_run: true, task: "fm:import_people", run: nil)
    ENV["DRY_RUN"] = dry_run ? "true" : "false"
    ENV["RUN"] = run
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    Rake::Task[task].reenable
    Rake::Task[task].invoke
    output.string
  rescue SystemExit => e
    # An escaped exit would end the whole suite as if it had passed, so fail the example instead.
    raise "#{task} aborted: #{e.message}"
  ensure
    $stdout = original_stdout
    ENV.delete("DRY_RUN")
    ENV.delete("RUN")
  end

  context "with no tag aliases recorded" do
    it "stops before reading a row" do
      expect { run_task(dry_run: false) }.to raise_error(/aborted: No tag aliases recorded/)
      expect(Person.where(filemaker_code: "00200")).to be_empty
    end
  end

  context "with tag aliases recorded" do
    before { create(:tag_alias) }

    it "rolls a dry run back and saves its report" do
      expect { run_task }.to change(ActiveStorage::Blob, :count).by(1)

      expect(Person.where(filemaker_code: "00200")).to be_empty
      expect(ActiveStorage::Blob.last.download).to include("Created", "DRY RUN")
    end

    it "writes on a real run" do
      output = run_task(dry_run: false)

      expect(Person.where(filemaker_code: "00200")).to be_present
      expect(output).to include("ActiveStorage::Blob.find(#{ActiveStorage::Blob.last.id}).download")
    end

    it "names the run so fm:undo_import_people can reverse it" do
      run = run_task(dry_run: false)[/ RUN=(fm-import-people-\d+)/, 1]

      run_task(task: "fm:undo_import_people", run:)
      expect(Person.where(filemaker_code: "00200")).to be_present

      run_task(task: "fm:undo_import_people", run:, dry_run: false)
      expect(Person.where(filemaker_code: "00200")).to be_empty
    end
  end
end
