class CreateWorkshopVariations < ActiveRecord::Migration
  def change
    create_table :workshop_variations do |t|
      t.references :workshop, index: true
      t.integer :variation_id

      t.timestamps null: false
    end
    add_foreign_key :workshop_variations, :workshops
  end
end
