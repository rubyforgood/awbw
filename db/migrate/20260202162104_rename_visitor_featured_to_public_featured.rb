class RenameVisitorFeaturedToPublicFeatured < ActiveRecord::Migration[8.1]
  def change
    rename_column :community_news, :visitor_featured, :public_featured
    rename_column :events, :visitor_featured, :public_featured
    rename_column :resources, :visitor_featured, :public_featured
    rename_column :stories, :visitor_featured, :public_featured
    rename_column :workshops, :visitor_featured, :public_featured
  end
end
