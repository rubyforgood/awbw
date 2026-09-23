class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices, if_not_exists: true do |t|
      t.string :number, null: false
      t.date :date, null: false
      t.integer :client_id, null: false
      t.string :client_type, null: false
      t.string :bill_to_name, null: false
      t.text :bill_to_address, null: false
      t.string :attention
      t.integer :total_cents, null: false, default: 0
      t.integer :created_by_id
      t.integer :updated_by_id

      t.timestamps
    end
    add_index :invoices, [:client_id, :client_type], if_not_exists: true
    add_index :invoices, :number, unique: true, if_not_exists: true
  end
end
