class AddWorkshopIdToReport < ActiveRecord::Migration
  def change
    add_column :reports, :workshop_id, :integer
  end
end
