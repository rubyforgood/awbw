require "rails_helper"
require "rake"

RSpec.describe "data:backfill_notification_stamps" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("data:backfill_notification_stamps")
  end

  before { Rake::Task["data:backfill_notification_stamps"].reenable }

  def run_task
    original = $stdout
    $stdout = StringIO.new
    Rake::Task["data:backfill_notification_stamps"].invoke
  ensure
    $stdout = original
  end

  let(:sender) { create(:user) }

  it "fills nil created_by/updated_by from the sender" do
    notification = create(:notification, sender: sender)
    notification.update_columns(created_by_id: nil, updated_by_id: nil)

    run_task

    notification.reload
    expect(notification.created_by).to eq(sender)
    expect(notification.updated_by).to eq(sender)
  end

  it "leaves a sender-less notification untouched" do
    notification = create(:notification, sender: nil)
    notification.update_columns(created_by_id: nil, updated_by_id: nil)

    run_task

    notification.reload
    expect(notification.created_by).to be_nil
    expect(notification.updated_by).to be_nil
  end

  it "does not overwrite a stamp that is already set" do
    editor = create(:user)
    notification = create(:notification, sender: sender)
    notification.update_columns(created_by_id: nil, updated_by_id: editor.id)

    run_task

    notification.reload
    expect(notification.created_by).to eq(sender)
    expect(notification.updated_by).to eq(editor)
  end
end
