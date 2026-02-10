class AddParentAndRootNotificationIdsToNotifications < ActiveRecord::Migration[8.1]
  def change
    # Add parent and root notification tracking
    add_column :notifications, :parent_notification_id, :integer, null: true
    add_column :notifications, :root_notification_id, :integer, null: true

    # Add indexes for better query performance
    add_index :notifications, :parent_notification_id
    add_index :notifications, :root_notification_id

    # Add foreign key constraints (optional but recommended)
    add_foreign_key :notifications, :notifications, column: :parent_notification_id
    add_foreign_key :notifications, :notifications, column: :root_notification_id
  end
end
