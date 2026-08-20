class AddStorySharePositionToSectorsAndCategories < ActiveRecord::Migration[7.2]
  def up
    add_column :sectors, :story_share_position, :integer unless column_exists?(:sectors, :story_share_position)
    add_column :categories, :story_share_position, :integer unless column_exists?(:categories, :story_share_position)
    add_index :sectors, :story_share_position unless index_exists?(:sectors, :story_share_position)
    add_index :categories, :story_share_position unless index_exists?(:categories, :story_share_position)
  end

  def down
    remove_index :sectors, :story_share_position if index_exists?(:sectors, :story_share_position)
    remove_index :categories, :story_share_position if index_exists?(:categories, :story_share_position)
    remove_column :sectors, :story_share_position if column_exists?(:sectors, :story_share_position)
    remove_column :categories, :story_share_position if column_exists?(:categories, :story_share_position)
  end
end
