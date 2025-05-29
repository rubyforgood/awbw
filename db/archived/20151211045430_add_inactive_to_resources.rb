class AddInactiveToResources < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :inactive, :boolean, default: true
  end
end
