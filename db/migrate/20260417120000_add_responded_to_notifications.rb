class AddRespondedToNotifications < ActiveRecord::Migration[8.1]
  def up
    add_column :notifications, :responded, :boolean, default: false, null: false
  end

  def down
    remove_column :notifications, :responded, if_exists: true
  end
end
