class AddHomeFeaturedStoriesLimitToSettings < ActiveRecord::Migration[8.1]
  def up
    add_column :settings, :home_featured_stories_limit, :integer unless column_exists?(:settings, :home_featured_stories_limit)
  end

  def down
    remove_column :settings, :home_featured_stories_limit if column_exists?(:settings, :home_featured_stories_limit)
  end
end
