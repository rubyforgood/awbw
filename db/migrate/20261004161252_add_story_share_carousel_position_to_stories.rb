class AddStoryShareCarouselPositionToStories < ActiveRecord::Migration[8.1]
  def up
    add_column :stories, :story_share_carousel_position, :integer
    add_index :stories, :story_share_carousel_position
  end

  def down
    remove_index :stories, :story_share_carousel_position, if_exists: true
    remove_column :stories, :story_share_carousel_position, if_exists: true
  end
end
