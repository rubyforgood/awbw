class AddPlannedGivingToGrants < ActiveRecord::Migration[8.1]
  def up
    add_column :grants, :planned_giving, :boolean, default: false, null: false
  end

  def down
    remove_column :grants, :planned_giving, if_exists: true
  end
end
