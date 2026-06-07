class AddSenderToNotifications < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:notifications, :sender_id)

    add_reference :notifications, :sender, type: :integer, null: true, foreign_key: { to_table: :users }
  end

  def down
    remove_reference :notifications, :sender, foreign_key: { to_table: :users } if column_exists?(:notifications, :sender_id)
  end
end
