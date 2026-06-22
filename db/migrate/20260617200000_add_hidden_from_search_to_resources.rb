class AddHiddenFromSearchToResources < ActiveRecord::Migration[8.1]
  def up
    add_column :resources, :hidden_from_search, :boolean, default: false, null: false
  end

  def down
    remove_column :resources, :hidden_from_search, if_exists: true
  end
end
