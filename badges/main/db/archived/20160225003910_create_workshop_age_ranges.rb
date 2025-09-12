class CreateWorkshopAgeRanges < ActiveRecord::Migration
  def change
    create_table :workshop_age_ranges do |t|
      t.references :workshop, index: true
      t.references :age_range, index: true

      t.timestamps null: false
    end
    add_foreign_key :workshop_age_ranges, :workshops
    add_foreign_key :workshop_age_ranges, :age_ranges
  end
end
