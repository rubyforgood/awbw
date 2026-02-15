class RemoveInactiveFromOrganizations < ActiveRecord::Migration[8.1]
  def change
    remove_column :organizations, :inactive, :boolean, default: false
  end
end
