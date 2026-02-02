class AddPublicToDashboardModels < ActiveRecord::Migration[8.1]
  def change
    add_column :community_news, :public, :boolean, default: false, null: false
    add_column :events, :public, :boolean, default: false, null: false
    add_column :resources, :public, :boolean, default: false, null: false
    add_column :stories, :public, :boolean, default: false, null: false
    add_column :workshops, :public, :boolean, default: false, null: false
  end
end
