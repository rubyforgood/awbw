class CreateQuotableItemQuotes < ActiveRecord::Migration
  def change
    create_table :quotable_item_quotes do |t|
      t.string :quotable_type
      t.integer :quotable_id
      t.integer :legacy_id
      t.references :quote, index: true

      t.timestamps null: false
    end
    add_foreign_key :quotable_item_quotes, :quotes
  end
end
