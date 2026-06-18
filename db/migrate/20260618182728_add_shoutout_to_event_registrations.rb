class AddShoutoutToEventRegistrations < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:event_registrations, :shoutout)
    add_column :event_registrations, :shoutout, :boolean, default: false, null: false
  end

  def down
    remove_column :event_registrations, :shoutout, if_exists: true
  end
end
