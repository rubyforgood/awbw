class AddFeaturedToStory < ActiveRecord::Migration[8.1]
  def change
    add_column :stories, :featured, :boolean, null: false, default: false
  end
end
