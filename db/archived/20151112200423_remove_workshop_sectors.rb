class RemoveWorkshopSectors < ActiveRecord::Migration[4.2]
  def change
    drop_table :workshop_sectors
  end
end
