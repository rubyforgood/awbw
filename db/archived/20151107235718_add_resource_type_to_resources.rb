class AddResourceTypeToResources < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :type, :string
  end
end
