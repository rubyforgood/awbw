class AddPaymentUnresolvedToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_registrations, :payment_unresolved, :boolean, default: false, null: false
    add_index :event_registrations, :payment_unresolved
  end
end
