class RenameIsTutorialToIsInstructional < ActiveRecord::Migration[8.1]
  def change
    rename_column :video_recordings, :is_tutorial, :is_instructional
    rename_index :video_recordings, "index_video_recordings_on_is_tutorial", "index_video_recordings_on_is_instructional"
  end
end
