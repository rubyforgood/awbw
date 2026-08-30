class AddOrganizationToResources < ActiveRecord::Migration[8.0]
  def up
    add_column :resources, :organization_id, :integer unless column_exists?(:resources, :organization_id)
    add_index :resources, :organization_id unless index_exists?(:resources, :organization_id)
    unless foreign_key_exists?(:resources, :organizations, column: :organization_id)
      add_foreign_key :resources, :organizations, column: :organization_id
    end
  end

  def down
    remove_foreign_key :resources, column: :organization_id, if_exists: true
    remove_index :resources, :organization_id, if_exists: true
    remove_column :resources, :organization_id, if_exists: true
  end
end
