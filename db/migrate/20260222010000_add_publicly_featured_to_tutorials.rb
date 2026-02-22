class AddPubliclyFeaturedToTutorials < ActiveRecord::Migration[8.0]
  def change
    add_column :tutorials, :publicly_featured, :boolean, default: false, null: false
  end
end
