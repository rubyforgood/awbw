class AddNameSpanishToCategoriesSectorsCategoryTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :name_spanish, :string
    add_column :sectors, :name_spanish, :string
    add_column :category_types, :name_spanish, :string
  end
end
