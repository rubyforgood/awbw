class AddRecipientNameToNotifications < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:notifications, :recipient_name)

    # Snapshot of the contact person's name at send time, resolved from
    # recipient_email. Cached so the name survives even if the Person record is
    # later nullified or deleted. Populated going forward only (no backfill).
    add_column :notifications, :recipient_name, :string
  end

  def down
    remove_column :notifications, :recipient_name, if_exists: true
  end
end
