class CreateCategories < ActiveRecord::Migration[4.2]
  def change
    create_table :categories do |t|
      t.references :metadatum, index: true
      t.string :name
      t.integer :legacy_id
      t.timestamps null: false
    end
    add_foreign_key :categories, :metadata
  end
end
