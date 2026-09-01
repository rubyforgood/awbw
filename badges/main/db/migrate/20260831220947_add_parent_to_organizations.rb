class AddParentToOrganizations < ActiveRecord::Migration[7.2]
  def up
    add_column :organizations, :parent_id, :integer unless column_exists?(:organizations, :parent_id)
    add_index :organizations, :parent_id unless index_exists?(:organizations, :parent_id)
    unless foreign_key_exists?(:organizations, column: :parent_id)
      add_foreign_key :organizations, :organizations, column: :parent_id
    end
  end

  def down
    remove_foreign_key :organizations, column: :parent_id if foreign_key_exists?(:organizations, column: :parent_id)
    remove_index :organizations, :parent_id if index_exists?(:organizations, :parent_id)
    remove_column :organizations, :parent_id if column_exists?(:organizations, :parent_id)
  end
end
