class ChangePaymentsToSti < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :type, :string, null: false

    add_column :payments, :pay_charge_id, :bigint
    add_column :payments, :check_number, :string

    remove_column :payments, :event_id
    remove_column :payments, :payable_type
    remove_column :payments, :payable_id
    remove_column :payments, :payment_type
    remove_column :payments, :stripe_payment_intent_id
    remove_column :payments, :stripe_charge_id
    remove_column :payments, :stripe_metadata
    remove_column :payments, :failure_code
    remove_column :payments, :failure_message
    remove_column :payments, :status
  end
end
