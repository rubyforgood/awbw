class AddFlaggedToNotifications < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:notifications, :flagged)
    add_column :notifications, :flagged, :boolean, null: false, default: false
  end

  def down
    remove_column :notifications, :flagged, if_exists: true
  end
end
