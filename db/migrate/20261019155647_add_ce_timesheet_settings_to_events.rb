class AddCeTimesheetSettingsToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :ce_timesheets_enabled, :boolean, default: true, null: false unless column_exists?(:events, :ce_timesheets_enabled)
    add_column :events, :ce_timesheet_opens_offset_minutes, :integer unless column_exists?(:events, :ce_timesheet_opens_offset_minutes)
    add_column :events, :ce_timesheet_closes_at, :datetime unless column_exists?(:events, :ce_timesheet_closes_at)
  end

  def down
    remove_column :events, :ce_timesheet_closes_at, if_exists: true
    remove_column :events, :ce_timesheet_opens_offset_minutes, if_exists: true
    remove_column :events, :ce_timesheets_enabled, if_exists: true
  end
end
