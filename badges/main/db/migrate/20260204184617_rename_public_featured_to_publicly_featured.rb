class RenamePublicFeaturedToPubliclyFeatured < ActiveRecord::Migration[8.1]
  def change
    rename_column :community_news, :public_featured, :publicly_featured
    rename_column :events, :public_featured, :publicly_featured
    rename_column :resources, :public_featured, :publicly_featured
    rename_column :stories, :public_featured, :publicly_featured
    rename_column :workshops, :public_featured, :publicly_featured
  end
end
