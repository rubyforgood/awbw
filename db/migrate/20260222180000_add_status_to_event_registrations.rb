class AddStatusToEventRegistrations < ActiveRecord::Migration[8.0]
  def up
    add_column :event_registrations, :status, :string, default: "registered", null: false
  end

  def down
    remove_column :event_registrations, :status
  end
end
