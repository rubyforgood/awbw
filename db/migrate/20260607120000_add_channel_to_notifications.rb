class AddChannelToNotifications < ActiveRecord::Migration[8.1]
  def up
    add_column :notifications, :channel, :string, null: false, default: "autoemail"
  end

  def down
    remove_column :notifications, :channel, if_exists: true
  end
end
