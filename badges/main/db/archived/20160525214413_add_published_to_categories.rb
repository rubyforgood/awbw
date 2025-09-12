class AddPublishedToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :published, :boolean, default: false
  end
end
