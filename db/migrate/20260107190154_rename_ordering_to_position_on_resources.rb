class RenameOrderingToPositionOnResources < ActiveRecord::Migration[8.1]
  def change
    rename_column :resources, :ordering, :position
  end
end
