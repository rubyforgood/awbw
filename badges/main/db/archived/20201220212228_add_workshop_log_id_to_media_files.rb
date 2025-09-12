class AddWorkshopLogIdToMediaFiles < ActiveRecord::Migration
  def change
    add_column :media_files, :workshop_log_id, :integer
  end
end
