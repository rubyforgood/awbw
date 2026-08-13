class AddDirectionToNotifications < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:notifications, :direction)

    # "outgoing" (sent to the person) vs "incoming" (sent by the person the
    # communication is about). Existing rows are outgoing — the portal has only
    # ever recorded messages sent to people.
    add_column :notifications, :direction, :string, default: "outgoing", null: false
  end

  def down
    remove_column :notifications, :direction, if_exists: true
  end
end
