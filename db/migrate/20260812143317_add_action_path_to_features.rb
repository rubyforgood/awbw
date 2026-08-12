class AddActionPathToFeatures < ActiveRecord::Migration[8.1]
  def change
    add_column :features, :action_path, :string
  end
end
