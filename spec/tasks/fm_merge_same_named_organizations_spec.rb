require "rails_helper"
require "rake"

RSpec.describe "fm:merge_same_named_organizations" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("fm:merge_same_named_organizations")
  end

  before do
    Setting.create!(import_user: create(:user))
    create(:staff_alias)
  end

  after { Current.reset }

  let!(:keeper) { create(:organization, name: "Harbor House Combined", filemaker_code: "P0001") }
  let!(:version) { create(:organization, name: "Harbor House Children's", filemaker_code: "P0002") }

  before { create(:affiliation, organization: keeper) }

  def run_task(dry_run: true)
    ENV["DRY_RUN"] = dry_run ? "true" : "false"
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    Rake::Task["fm:merge_same_named_organizations"].reenable
    Rake::Task["fm:merge_same_named_organizations"].invoke
    output.string
  rescue SystemExit => e
    raise "fm:merge_same_named_organizations aborted: #{e.message}"
  ensure
    $stdout = original_stdout
    ENV.delete("DRY_RUN")
  end

  it "lists every merge on a dry run and writes nothing" do
    output = run_task

    expect(output).to include("Merged (1)", "##{version.id} Harbor House Children's into ##{keeper.id}", "Renamed (1)", "DRY RUN")
    expect(Organization.count).to eq(2)
  end

  it "merges on a real run and says fm:undo_import won't reverse it" do
    output = run_task(dry_run: false)

    expect(Organization.sole).to have_attributes(id: keeper.id, name: "Harbor House", filemaker_code: "P0001, P0002")
    expect(output).to include("fm:undo_import doesn't reverse merges")
    expect(output).not_to include("To reverse this run")
  end
end
