class CreateWorkshopQuotes < ActiveRecord::Migration
  def change
    create_table :workshop_quotes do |t|
      t.string :quote
      t.boolean :inactive, default: true
      t.integer :legacy_id
      t.boolean :legacy, default: false

      t.timestamps null: false
    end
  end
end
