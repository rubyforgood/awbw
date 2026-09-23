class CreateInvoiceLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_line_items, if_not_exists: true do |t|
      t.references :invoice, null: false, foreign_key: true
      t.date :date
      t.text :description, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_cents, null: false, default: 0

      t.timestamps
    end
    add_index :invoice_line_items, :invoice_id, if_not_exists: true
  end
end
