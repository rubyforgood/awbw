class RenameYoutubeVideos < ActiveRecord::Migration[8.0]
  def change
    rename_table :tutorials, :youtube_videos

    add_column :youtube_videos, :is_tutorial, :boolean, default: true, null: false
    add_column :youtube_videos, :is_podcast, :boolean, default: false, null: false
    add_index :youtube_videos, :is_tutorial
    add_index :youtube_videos, :is_podcast
  end
end
