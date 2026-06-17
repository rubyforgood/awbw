class AddDescriptionToSectors < ActiveRecord::Migration[8.1]
  def up
    add_column :sectors, :description, :text unless column_exists?(:sectors, :description)
  end

  def down
    remove_column :sectors, :description, :text, if_exists: true
  end
end
