require "rails_helper"
require "rake"

RSpec.describe "fm:purge_import_activity" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("fm:purge_import_activity")
  end

  def track(properties)
    create(:ahoy_event, name: "create.organization", properties:)
  end

  def run_task(run:, dry_run: true, force: false)
    ENV["RUN"] = run
    ENV["DRY_RUN"] = dry_run ? "true" : "false"
    ENV["FORCE"] = "true" if force
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    Rake::Task["fm:purge_import_activity"].reenable
    Rake::Task["fm:purge_import_activity"].invoke
    output.string
  rescue SystemExit => e
    raise "fm:purge_import_activity aborted: #{e.message}"
  ensure
    $stdout = original_stdout
    %w[RUN DRY_RUN FORCE].each { |key| ENV.delete(key) }
  end

  let!(:imported) { track("import_run" => "fm-import-1") }
  let!(:other_run) { track("import_run" => "fm-import-2") }

  it "refuses a run that hasn't been undone" do
    expect { run_task(run: "fm-import-1", dry_run: false) }.to raise_error(/hasn't been undone/)
    expect(Ahoy::Event.count).to eq(2)
  end

  context "once the run is undone" do
    let!(:undone) { track("undone_run" => "fm-import-1") }

    it "counts on a dry run and deletes nothing" do
      expect(run_task(run: "fm-import-1")).to include("2 events would be deleted")
      expect(Ahoy::Event.count).to eq(3)
    end

    it "deletes the run's activity and its undo's, leaving other runs" do
      run_task(run: "fm-import-1", dry_run: false)

      expect(Ahoy::Event.all).to eq([ other_run ])
    end
  end

  it "deletes a run never undone with FORCE=true" do
    run_task(run: "fm-import-1", dry_run: false, force: true)

    expect(Ahoy::Event.all).to eq([ other_run ])
  end
end
