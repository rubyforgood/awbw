class ChangePaymentUnresolvedDefaultToNil < ActiveRecord::Migration[8.1]
  def change
    change_column_null :event_registrations, :payment_unresolved, true
    change_column_default :event_registrations, :payment_unresolved, from: false, to: nil
  end
end
