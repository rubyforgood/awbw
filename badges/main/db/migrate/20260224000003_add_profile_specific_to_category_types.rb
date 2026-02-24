class AddProfileSpecificToCategoryTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :category_types, :profile_specific, :boolean, default: false, null: false
  end
end
