class RemoveReportIdFromNotifications < ActiveRecord::Migration
  def up
    remove_foreign_key :notifications, :reports
    remove_column :notifications, :report_id
  end

  def down
    add_column :notifications, :report_id, :integer
    add_foreign_key :notifications, :reports
  end
end
