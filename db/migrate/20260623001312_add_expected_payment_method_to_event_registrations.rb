class AddExpectedPaymentMethodToEventRegistrations < ActiveRecord::Migration[8.1]
  def up
    add_column :event_registrations, :expected_payment_method, :string
  end

  def down
    remove_column :event_registrations, :expected_payment_method, if_exists: true
  end
end
