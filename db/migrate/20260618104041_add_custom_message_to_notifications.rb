class AddCustomMessageToNotifications < ActiveRecord::Migration[8.1]
  # Optional admin-authored message included in the email a notification
  # represents (currently the bulk event reminder). Stored so the async
  # NotificationMailerJob — and any later resend — can re-render the exact email
  # the admin composed. NULL means the notification carries no custom message.
  def up
    add_column :notifications, :custom_message, :text unless column_exists?(:notifications, :custom_message)
  end

  def down
    remove_column :notifications, :custom_message, if_exists: true
  end
end
