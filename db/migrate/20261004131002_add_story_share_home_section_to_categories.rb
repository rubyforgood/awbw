class AddStoryShareHomeSectionToCategories < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:categories, :story_share_home_section)
    add_column :categories, :story_share_home_section, :boolean, null: false, default: true
  end

  def down
    remove_column :categories, :story_share_home_section if column_exists?(:categories, :story_share_home_section)
  end
end
