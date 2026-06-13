class AddDescriptionToCategories < ActiveRecord::Migration[8.1]
  def up
    add_column :categories, :description, :text unless column_exists?(:categories, :description)
  end

  def down
    remove_column :categories, :description, :text, if_exists: true
  end
end
