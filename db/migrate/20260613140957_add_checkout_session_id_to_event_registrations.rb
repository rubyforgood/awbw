class AddCheckoutSessionIdToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_registrations, :checkout_session_id, :string
    add_index :event_registrations, :checkout_session_id
  end
end
