class AddStoryShareHomeSectionToSectors < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:sectors, :story_share_home_section)
    add_column :sectors, :story_share_home_section, :boolean, null: false, default: true
  end

  def down
    remove_column :sectors, :story_share_home_section if column_exists?(:sectors, :story_share_home_section)
  end
end
