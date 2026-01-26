class AddPaymentsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :payer, polymorphic: true, null: false

      t.references :payable, polymorphic: true, null: false

      t.integer :amount_cents, null: false
      t.string  :currency, null: false, default: "usd"

      t.string :stripe_payment_intent_id, null: false
      t.string :stripe_charge_id

      t.string :status, null: false
      t.string :failure_code
      t.string :failure_message

      t.json :stripe_metadata

      t.timestamps
    end

    add_index :payments, :stripe_payment_intent_id, unique: true
    add_index :payments, :stripe_charge_id
    add_index :payments, [ :payer_type, :payer_id ]
    add_index :payments, [ :payable_type, :payable_id ]
    add_index :payments, [ :payable_type, :payable_id, :status ]
  end
end
