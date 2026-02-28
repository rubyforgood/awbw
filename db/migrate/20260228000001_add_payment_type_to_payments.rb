class AddPaymentTypeToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :payment_type, :string, default: "stripe", null: false unless column_exists?(:payments, :payment_type)
    change_column_null :payments, :stripe_payment_intent_id, true
  end
end
