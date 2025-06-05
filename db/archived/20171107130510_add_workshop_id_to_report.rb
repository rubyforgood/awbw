class AddWorkshopIdToReport < ActiveRecord::Migration[4.2]
  def change
    add_column :reports, :workshop_id, :integer
  end
end
