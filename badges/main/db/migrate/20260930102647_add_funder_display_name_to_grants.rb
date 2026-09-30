class AddFunderDisplayNameToGrants < ActiveRecord::Migration[8.1]
  def up
    add_column :grants, :funder_display_name, :string
  end

  def down
    remove_column :grants, :funder_display_name, if_exists: true
  end
end
