class RenameUserIdToCreatedById < ActiveRecord::Migration[8.0]
  def change
    rename_column :resources, :user_id, :created_by_id
    rename_column :reports, :user_id, :created_by_id
    rename_column :workshops, :user_id, :created_by_id
  end
end
