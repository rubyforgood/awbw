class RenamePubliclyVisibleToInactiveInEvents < ActiveRecord::Migration[8.1]
  def change
    rename_column :events, :publicly_visible, :inactive
    change_column_default :events, :inactive, true
  end
end
