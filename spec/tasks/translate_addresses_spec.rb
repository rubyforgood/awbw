require "rails_helper"
require "rake"

RSpec.describe "data:translate_addresses" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("data:translate_addresses")
  end

  before { Rake::Task["data:translate_addresses"].reenable }

  after { ENV.delete("DRY_RUN") }

  def run_task
    original = $stdout
    $stdout = StringIO.new
    Rake::Task["data:translate_addresses"].invoke
    $stdout.string
  ensure
    $stdout = original
  end

  def address_with(country:, state:)
    create(:address, addressable: create(:person)).tap { |address| address.update_columns(country:, state:) }
  end

  def saved_report = ActiveStorage::Blob.order(:id).last

  def report_text = saved_report.download.force_encoding(Encoding::UTF_8)

  it "previews by default, writing no addresses, and saves the report" do
    usa = address_with(country: "USA", state: "TX")
    address_with(country: "Narnia", state: "Central Region")

    output = run_task

    expect(usa.reload.country).to eq("USA")
    expect(output).to include("DRY RUN", "Narnia", "Report saved")
    expect(saved_report.filename.to_s).to match(/\Atranslate-addresses-\d{8}-\d{6}-dry-run\.txt\z/)
    expect(report_text).to include("Address country: \"USA\" → \"United States\"", "Narnia")
  end

  it "writes with DRY_RUN=false and saves that run's report too" do
    usa = address_with(country: "USA", state: "TX")
    ENV["DRY_RUN"] = "false"

    run_task

    expect(usa.reload.country).to eq("United States")
    expect(saved_report.filename.to_s).not_to include("dry-run")
    expect(report_text).to include("Done.")
  end
end
