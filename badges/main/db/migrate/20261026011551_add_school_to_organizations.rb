class AddSchoolToOrganizations < ActiveRecord::Migration[8.1]
  def up
    add_column :organizations, :school, :boolean, default: false, null: false
  end

  def down
    remove_column :organizations, :school, if_exists: true
  end
end
