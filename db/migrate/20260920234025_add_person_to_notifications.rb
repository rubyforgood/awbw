class AddPersonToNotifications < ActiveRecord::Migration[7.2]
  def up
    add_reference :notifications, :person, foreign_key: true, null: true, index: true
  end

  def down
    remove_reference :notifications, :person, foreign_key: true, if_exists: true
  end
end
