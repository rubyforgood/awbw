class AddHiddenFromSearchToAssets < ActiveRecord::Migration[8.1]
  def up
    add_column :assets, :hidden_from_search, :boolean, default: false, null: false
  end

  def down
    remove_column :assets, :hidden_from_search, if_exists: true
  end
end
