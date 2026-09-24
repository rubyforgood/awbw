class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.string :number, null: false
      t.date :date, null: false
      t.references :client, polymorphic: true, null: false
      t.text :bill_to_address, null: false
      t.references :attention_person, foreign_key: { to_table: :people }
      t.integer :total_cents, null: false, default: 0
      t.integer :created_by_id
      t.integer :updated_by_id

      t.timestamps
    end
    add_index :invoices, :number, unique: true

    create_table :invoice_line_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.date :date
      t.text :description, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_cents, null: false, default: 0

      t.timestamps
    end
  end
end
