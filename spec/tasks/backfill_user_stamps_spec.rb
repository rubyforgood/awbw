require "rails_helper"
require "rake"

RSpec.describe "data:backfill_user_stamps" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("data:backfill_user_stamps")
  end

  before { Rake::Task["data:backfill_user_stamps"].reenable }

  def run_task
    original = $stdout
    $stdout = StringIO.new
    Rake::Task["data:backfill_user_stamps"].invoke
  ensure
    $stdout = original
  end

  let(:early_editor) { create(:user) }
  let(:late_editor)  { create(:user) }

  it "backfills updated_by_id from the most recent update event's user" do
    log = create(:workshop_log)
    log.update_columns(updated_by_id: nil)

    create(:ahoy_event, name: "update.workshop_log", user: early_editor, time: 2.days.ago,
                        properties: { resource_type: "WorkshopLog", resource_id: log.id })
    create(:ahoy_event, name: "update.workshop_log", user: late_editor, time: 1.hour.ago,
                        properties: { resource_type: "WorkshopLog", resource_id: log.id })

    run_task

    expect(log.reload.updated_by_id).to eq(late_editor.id)
  end

  it "leaves updated_by_id untouched when there is no update event" do
    log = create(:workshop_log)
    log.update_columns(updated_by_id: nil)

    run_task

    expect(log.reload.updated_by_id).to be_nil
  end

  it "does not overwrite an already-stamped updated_by_id" do
    existing = create(:user)
    log = create(:workshop_log)
    log.update_columns(updated_by_id: existing.id)

    create(:ahoy_event, name: "update.workshop_log", user: late_editor, time: 1.hour.ago,
                        properties: { resource_type: "WorkshopLog", resource_id: log.id })

    run_task

    expect(log.reload.updated_by_id).to eq(existing.id)
  end
end
