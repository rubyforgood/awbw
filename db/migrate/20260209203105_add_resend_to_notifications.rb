class AddResendToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :resend, :boolean, default: false, null: false
  end
end
