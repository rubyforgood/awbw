class AddInMemoriamToGrants < ActiveRecord::Migration[8.1]
  def up
    add_column :grants, :in_memoriam, :boolean, default: false, null: false
  end

  def down
    remove_column :grants, :in_memoriam, if_exists: true
  end
end
