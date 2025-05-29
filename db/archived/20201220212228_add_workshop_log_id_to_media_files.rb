class AddWorkshopLogIdToMediaFiles < ActiveRecord::Migration[4.2]
  def change
    add_column :media_files, :workshop_log_id, :integer
  end
end
