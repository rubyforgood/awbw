class AddStatusBeforeTransferToEventRegistrations < ActiveRecord::Migration[8.1]
  def up
    add_column :event_registrations, :status_before_transfer, :string
  end

  def down
    remove_column :event_registrations, :status_before_transfer, if_exists: true
  end
end
