class AddInactiveToResources < ActiveRecord::Migration
  def change
    add_column :resources, :inactive, :boolean, default: true
  end
end
