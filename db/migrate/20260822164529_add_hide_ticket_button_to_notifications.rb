class AddHideTicketButtonToNotifications < ActiveRecord::Migration[8.1]
  def up
    add_column :notifications, :hide_ticket_button, :boolean, default: false, null: false
  end

  def down
    remove_column :notifications, :hide_ticket_button, if_exists: true
  end
end
