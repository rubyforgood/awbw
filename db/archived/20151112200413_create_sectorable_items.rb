class CreateSectorableItems < ActiveRecord::Migration
  def change
    create_table :sectorable_items do |t|
      t.integer :sectorable_id
      t.string :sectorable_type
      t.references :sector, index: true

      t.timestamps null: false
    end
    add_foreign_key :sectorable_items, :sectors
  end
end
