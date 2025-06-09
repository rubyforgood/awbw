class CreateCategorizableItems < ActiveRecord::Migration
  def change
    create_table :categorizable_items do |t|
      t.integer :categorizable_id
      t.string :categorizable_type
      t.references :category, index: true
      t.integer :legacy_id
      t.timestamps null: false
    end
  end
end
