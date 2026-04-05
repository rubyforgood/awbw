class RemoveUniquePositionIndexFromCategories < ActiveRecord::Migration[8.1]
  def up
    remove_index :categories, name: "index_categories_on_category_type_id_and_position"
    add_index :categories, [ :category_type_id, :position ],
              name: "index_categories_on_category_type_id_and_position"
  end

  def down
    remove_index :categories, name: "index_categories_on_category_type_id_and_position"
    add_index :categories, [ :category_type_id, :position ],
              name: "index_categories_on_category_type_id_and_position",
              unique: true
  end
end
