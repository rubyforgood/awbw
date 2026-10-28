class AddSavedCardMembershipFields < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :autopay_on, :boolean, default: false, null: false
    add_column :memberships, :locked_at, :datetime
    add_column :membership_invoices, :payment_in_progress_at, :datetime

    create_table :membership_charge_attempts do |t|
      t.references :membership_invoice, null: false, foreign_key: true
      t.integer :attempt_number, null: false
      t.string :status, null: false, default: "pending"
      t.string :payment_intent_id
      t.references :pay_charge, foreign_key: true
      t.integer :amount_cents, null: false, default: 0
      t.string :error_code
      t.text :error_message
      t.datetime :attempted_at
      t.date :next_attempt_on
      t.timestamps
    end

    add_index :membership_charge_attempts,
              [ :membership_invoice_id, :attempt_number ],
              unique: true,
              name: "index_membership_charge_attempts_on_invoice_and_attempt"
    add_index :membership_charge_attempts, :status
  end
end
