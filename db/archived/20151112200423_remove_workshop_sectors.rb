class RemoveWorkshopSectors < ActiveRecord::Migration
  def change
    drop_table :workshop_sectors
  end
end
