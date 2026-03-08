class RenameVideoRecordings < ActiveRecord::Migration[8.0]
  def change
    rename_table :tutorials, :video_recordings

    add_column :video_recordings, :is_instructional, :boolean, default: true, null: false
    add_column :video_recordings, :is_podcast, :boolean, default: false, null: false
    add_index :video_recordings, :is_instructional
    add_index :video_recordings, :is_podcast
  end
end
