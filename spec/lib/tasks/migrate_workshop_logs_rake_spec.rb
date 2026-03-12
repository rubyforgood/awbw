require "rails_helper"
require "rake"

RSpec.describe "workshop_logs:migrate_from_reports" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("workshop_logs:migrate_from_reports")
  end

  around do |example|
    original_stdout = $stdout
    $stdout = StringIO.new
    example.run
  ensure
    $stdout = original_stdout
  end

  before do
    Rake::Task["workshop_logs:migrate_from_reports"].reenable
    # Ensure clean state — clear any stale data so the rake task
    # only processes this test's report
    conn.execute("UPDATE report_form_field_answers SET workshop_log_id = NULL WHERE workshop_log_id IS NOT NULL")
    conn.execute("DELETE FROM workshop_logs")
    conn.execute("UPDATE report_form_field_answers SET report_id = NULL WHERE report_id IN (SELECT id FROM reports WHERE type = 'WorkshopLog')")
    conn.execute("DELETE FROM reports WHERE type = 'WorkshopLog'")
  end

  let(:conn) { ActiveRecord::Base.connection }
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:windows_type) { create(:windows_type) }
  let(:workshop) { create(:workshop) }

  def insert_report_as_workshop_log(attrs = {})
    defaults = {
      type: "WorkshopLog",
      created_by_id: user.id,
      organization_id: organization.id,
      windows_type_id: windows_type.id,
      workshop_id: workshop.id,
      date: Date.current,
      rating: 0,
      children_first_time: 1,
      children_ongoing: 2,
      teens_first_time: 3,
      teens_ongoing: 4,
      adults_first_time: 5,
      adults_ongoing: 6,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)

    columns = defaults.keys.join(", ")
    placeholders = defaults.values.map { |v| conn.quote(v) }.join(", ")
    conn.execute("INSERT INTO reports (#{columns}) VALUES (#{placeholders})")
    conn.execute("SELECT LAST_INSERT_ID()").first[0]
  end

  it "copies WorkshopLog records from reports to workshop_logs" do
    report_id = insert_report_as_workshop_log

    expect { Rake::Task["workshop_logs:migrate_from_reports"].invoke }
      .to change { conn.execute("SELECT COUNT(*) FROM workshop_logs").first[0] }.by(1)

    row = conn.execute("SELECT * FROM workshop_logs WHERE id = #{report_id}").first
    expect(row).to be_present
  end

  it "preserves record IDs" do
    report_id = insert_report_as_workshop_log

    Rake::Task["workshop_logs:migrate_from_reports"].invoke

    wl_ids = conn.execute("SELECT id FROM workshop_logs").map { |r| r[0] }
    expect(wl_ids).to include(report_id)
  end

  it "migrates report_form_field_answers" do
    report_id = insert_report_as_workshop_log
    form_field = create(:form_field)
    answer_option = create(:answer_option)
    conn.execute(<<~SQL)
      INSERT INTO report_form_field_answers (report_id, form_field_id, answer_option_id, answer, created_at, updated_at)
      VALUES (#{report_id}, #{form_field.id}, #{answer_option.id}, 'test answer', NOW(), NOW())
    SQL

    Rake::Task["workshop_logs:migrate_from_reports"].invoke

    wl_count = conn.execute("SELECT COUNT(*) FROM workshop_logs WHERE id = #{report_id}").first[0]
    expect(wl_count).to eq(1), "Expected workshop_log #{report_id} to exist after migration"

    rffa = conn.execute("SELECT report_id, workshop_log_id FROM report_form_field_answers WHERE workshop_log_id = #{report_id}").first
    expect(rffa).to be_present
    expect(rffa[0]).to be_nil # report_id nulled
    expect(rffa[1]).to eq(report_id) # workshop_log_id set
  end

  it "updates active_storage_attachments record_type" do
    report_id = insert_report_as_workshop_log
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("test"), filename: "test.txt")
    conn.execute(<<~SQL)
      INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at)
      VALUES ('image', 'Report', #{report_id}, #{blob.id}, NOW())
    SQL

    Rake::Task["workshop_logs:migrate_from_reports"].invoke

    asa = conn.execute("SELECT record_type FROM active_storage_attachments WHERE record_id = #{report_id} AND name = 'image'").first
    expect(asa[0]).to eq("WorkshopLog")
  end

  it "updates assets owner_type" do
    report_id = insert_report_as_workshop_log
    conn.execute(<<~SQL)
      INSERT INTO assets (owner_type, owner_id, type, created_at, updated_at)
      VALUES ('Report', #{report_id}, 'GalleryAsset', NOW(), NOW())
    SQL

    Rake::Task["workshop_logs:migrate_from_reports"].invoke

    asset = conn.execute("SELECT owner_type FROM assets WHERE owner_id = #{report_id}").first
    expect(asset[0]).to eq("WorkshopLog")
  end

  it "updates quotable_item_quotes quotable_type" do
    report_id = insert_report_as_workshop_log
    quote = create(:quote)
    conn.execute(<<~SQL)
      INSERT INTO quotable_item_quotes (quotable_type, quotable_id, quote_id, created_at, updated_at)
      VALUES ('Report', #{report_id}, #{quote.id}, NOW(), NOW())
    SQL

    Rake::Task["workshop_logs:migrate_from_reports"].invoke

    qiq = conn.execute("SELECT quotable_type FROM quotable_item_quotes WHERE quotable_id = #{report_id}").first
    expect(qiq[0]).to eq("WorkshopLog")
  end

  it "does not delete WorkshopLog records from reports table" do
    insert_report_as_workshop_log

    Rake::Task["workshop_logs:migrate_from_reports"].invoke

    count = conn.execute("SELECT COUNT(*) FROM reports WHERE type = 'WorkshopLog'").first[0]
    expect(count).to eq(1)
  end

  it "does not affect non-WorkshopLog reports" do
    insert_report_as_workshop_log
    conn.execute(<<~SQL)
      INSERT INTO reports (type, created_by_id, organization_id, windows_type_id, date, has_attachment, created_at, updated_at)
      VALUES ('MonthlyReport', #{user.id}, #{organization.id}, #{windows_type.id}, '#{Date.current}', false, NOW(), NOW())
    SQL

    Rake::Task["workshop_logs:migrate_from_reports"].invoke

    count = conn.execute("SELECT COUNT(*) FROM reports WHERE type = 'MonthlyReport'").first[0]
    expect(count).to eq(1)
  end

  it "rolls back all changes if any step fails" do
    insert_report_as_workshop_log

    allow(conn).to receive(:execute).and_wrap_original do |method, *args|
      # Fail on the sectorable_items UPDATE (after INSERT has happened)
      if args[0]&.include?("UPDATE sectorable_items")
        raise ActiveRecord::StatementInvalid, "simulated failure"
      end
      method.call(*args)
    end

    expect { Rake::Task["workshop_logs:migrate_from_reports"].invoke }.to raise_error(ActiveRecord::StatementInvalid)

    # workshop_logs should be empty due to rollback
    count = conn.execute("SELECT COUNT(*) FROM workshop_logs").first[0]
    expect(count).to eq(0)
  end
end
