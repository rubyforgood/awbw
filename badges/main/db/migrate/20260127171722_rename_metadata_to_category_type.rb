class RenameMetadataToCategoryType < ActiveRecord::Migration[8.1]
  def change
    rename_table :metadata, :category_types
    rename_column :categories, :metadatum_id, :category_type_id
  end
end
