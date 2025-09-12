class CreateWorkshopSectors < ActiveRecord::Migration
  def change
    create_table :workshop_sectors do |t|
      t.references :workshop, index: true
      t.references :sector, index: true

      t.timestamps null: false
    end
    add_foreign_key :workshop_sectors, :workshops
    add_foreign_key :workshop_sectors, :sectors
  end
end
