class AddStoryShareFeaturedToStories < ActiveRecord::Migration[8.1]
  def up
    add_column :stories, :story_share_featured, :boolean, default: false, null: false unless column_exists?(:stories, :story_share_featured)
  end

  def down
    remove_column :stories, :story_share_featured if column_exists?(:stories, :story_share_featured)
  end
end
