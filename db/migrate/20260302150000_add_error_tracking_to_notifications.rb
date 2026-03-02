class AddErrorTrackingToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :error_message, :text
    add_column :notifications, :error_class, :string
    add_column :notifications, :error_at, :datetime
  end
end
