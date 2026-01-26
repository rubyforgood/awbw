class AddVistorFeaturedToDashboardModels < ActiveRecord::Migration[8.1]
  def change
    add_column :workshops, :visitor_featured, :boolean, default: false, null: false
    add_column :resources, :visitor_featured, :boolean, default: false, null: false
    add_column :stories, :visitor_featured, :boolean, default: false, null: false
    add_column :community_news, :visitor_featured, :boolean, default: false, null: false
    add_column :events, :visitor_featured, :boolean, default: false, null: false
  end
end
