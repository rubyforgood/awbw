require "rails_helper"
require "rake"

RSpec.describe "data:resolve_resource_organizations" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("data:resolve_resource_organizations")
  end

  before do
    Rake::Task["data:resolve_resource_organizations"].reenable
  end

  let!(:unknown_status) { create(:organization_status, name: "Unknown") }

  def run_task(dry_run: false)
    ENV["DRY_RUN"] = dry_run ? "true" : "false"
    suppress_output { Rake::Task["data:resolve_resource_organizations"].invoke }
  ensure
    ENV.delete("DRY_RUN")
  end

  def suppress_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end

  it "links a resource to an existing organization matched by name (case-insensitive)" do
    org = create(:organization, name: "Harbor House")
    resource = create(:resource, agency: "harbor house")

    run_task

    expect(resource.reload.organization).to eq(org)
  end

  it "creates an Unknown-status organization and links it when no match exists" do
    resource = create(:resource, agency: "Brand New Org")

    expect { run_task }.to change(Organization, :count).by(1)

    org = resource.reload.organization
    expect(org.name).to eq("Brand New Org")
    expect(org.organization_status).to eq(unknown_status)
  end

  it "reuses a single created org for two resources sharing the same agency name" do
    r1 = create(:resource, agency: "Shared Name")
    r2 = create(:resource, agency: "shared name")

    expect { run_task }.to change(Organization, :count).by(1)

    expect(r1.reload.organization).to eq(r2.reload.organization)
  end

  it "skips a resource whose agency name is ambiguous across multiple orgs" do
    create(:organization, name: "Twins")
    create(:organization, name: "Twins")
    resource = create(:resource, agency: "Twins")

    run_task

    expect(resource.reload.organization_id).to be_nil
  end

  it "leaves an already-linked resource untouched" do
    existing = create(:organization, name: "Existing Link")
    other = create(:organization, name: "Someplace Else")
    resource = create(:resource, agency: "Someplace Else", organization: existing)

    run_task

    expect(resource.reload.organization).to eq(existing)
    expect(resource.organization).not_to eq(other)
  end

  it "writes nothing on a dry run" do
    resource = create(:resource, agency: "Dry Run Org")

    expect { run_task(dry_run: true) }.not_to change(Organization, :count)
    expect(resource.reload.organization_id).to be_nil
  end
end
