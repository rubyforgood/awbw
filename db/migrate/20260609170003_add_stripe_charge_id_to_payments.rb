class AddStripeChargeIdToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :stripe_charge_id, :string
    add_index :payments, :stripe_charge_id, unique: true
  end
end
