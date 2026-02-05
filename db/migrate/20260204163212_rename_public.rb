class RenamePublic < ActiveRecord::Migration[8.1]
  def change
    rename_column :community_news, :public, :publicly_visible
    rename_column :events, :public, :publicly_visible
    rename_column :resources, :public, :publicly_visible
    rename_column :stories, :public, :publicly_visible
    rename_column :workshops, :public, :publicly_visible
  end
end
