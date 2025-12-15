class CreateYoutubeVideo < ActiveRecord::Migration[8.1]
  def change
    create_table :youtube_videos do |t|
      t.string :url

      t.timestamps
    end
  end
end
