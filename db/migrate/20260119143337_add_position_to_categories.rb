class AddPositionToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :position, :integer, null: false, default: 10
  end
end
