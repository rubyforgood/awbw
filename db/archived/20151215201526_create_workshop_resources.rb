class CreateWorkshopResources < ActiveRecord::Migration
  def change
    create_table :workshop_resources do |t|
      t.references :workshop, index: true
      t.references :resource, index: true

      t.timestamps null: false
    end
    add_foreign_key :workshop_resources, :workshops
    add_foreign_key :workshop_resources, :resources
  end
end
