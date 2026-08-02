class AddBulkEmailFieldsToNotifications < ActiveRecord::Migration[8.1]
  def change
    # The recipient as a record (populated when known), so a bulk delivery and a
    # regular one share one signature — today recipients are email-string-only.
    add_column :notifications, :person_id, :bigint
    add_index :notifications, :person_id

    # Batch membership: a bulk child points at its FYI parent. Kept separate from
    # parent_notification_id / root_notification_id, which mean "resend chain".
    add_column :notifications, :batch_root_notification_id, :bigint
    add_index :notifications, :batch_root_notification_id
  end
end
