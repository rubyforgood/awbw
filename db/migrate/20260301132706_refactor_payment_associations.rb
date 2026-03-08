class RefactorPaymentAssociations < ActiveRecord::Migration[8.1]
  def change
    # Remove polymorphic payable from payments
    remove_index :payments, name: "index_payments_on_payable_type_and_payable_id_and_status"
    remove_index :payments, name: "index_payments_on_payable"
    remove_column :payments, :payable_type, :string, null: false
    remove_column :payments, :payable_id, :bigint, null: false

    # Payer is now a direct FK to people (instead of polymorphic)
    remove_index :payments, name: "index_payments_on_payer"
    remove_column :payments, :payer_type, :string, null: false
    add_index :payments, :payer_id
    add_foreign_key :payments, :people, column: :payer_id

    # stripe_payment_intent_id is no longer required
    change_column_null :payments, :stripe_payment_intent_id, true

    # EventRegistration belongs_to :payment (singular, direct FK)
    add_reference :event_registrations, :payment, null: true, foreign_key: true
  end
end
