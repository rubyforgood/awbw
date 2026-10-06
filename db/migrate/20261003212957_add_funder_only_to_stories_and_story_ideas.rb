class AddFunderOnlyToStoriesAndStoryIdeas < ActiveRecord::Migration[8.0]
  def up
    add_column :stories, :funder_only, :boolean, default: false, null: false unless column_exists?(:stories, :funder_only)
    add_column :story_ideas, :funder_only, :boolean, default: false, null: false unless column_exists?(:story_ideas, :funder_only)
  end

  def down
    remove_column :stories, :funder_only if column_exists?(:stories, :funder_only)
    remove_column :story_ideas, :funder_only if column_exists?(:story_ideas, :funder_only)
  end
end
