class AddCustomSubjectToNotifications < ActiveRecord::Migration[8.1]
  # Optional admin-authored subject line for the email a notification represents
  # (currently the bulk event reminder). Stored alongside custom_message so the
  # async NotificationMailerJob — and any later resend — can re-send the exact
  # subject the admin composed. NULL means the email falls back to its default
  # computed subject.
  def up
    add_column :notifications, :custom_subject, :string unless column_exists?(:notifications, :custom_subject)
  end

  def down
    remove_column :notifications, :custom_subject, if_exists: true
  end
end
