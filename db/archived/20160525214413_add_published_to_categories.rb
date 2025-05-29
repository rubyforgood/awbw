class AddPublishedToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :published, :boolean, default: false
  end
end
