class AddCheckoutSessionIdAndPaymentUnresolvedToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_registrations, :checkout_session_id, :string
    add_index :event_registrations, :checkout_session_id
    add_column :event_registrations, :payment_unresolved, :boolean
    add_index :event_registrations, :payment_unresolved
  end
end
