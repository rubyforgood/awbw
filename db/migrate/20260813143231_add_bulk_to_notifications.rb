class AddBulkToNotifications < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:notifications, :bulk)

    # Marks a communication that went out as part of a bulk send. The bulk_payment_*
    # kinds are already unambiguous from their kind alone; this flag exists for the
    # bulk sends whose kind is shared with one-off sends — bulk reminders
    # (event_registration_reminder) and bulk invites (account_confirmation).
    add_column :notifications, :bulk, :boolean, default: false, null: false
  end

  def down
    remove_column :notifications, :bulk, if_exists: true
  end
end
