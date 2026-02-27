class AddPaymentTypeToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :payment_type, :string, default: "stripe", null: false
  end
end
