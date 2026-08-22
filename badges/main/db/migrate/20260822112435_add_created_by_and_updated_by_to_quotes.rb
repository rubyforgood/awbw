class AddCreatedByAndUpdatedByToQuotes < ActiveRecord::Migration[7.2]
  def up
    add_column :quotes, :created_by_id, :integer unless column_exists?(:quotes, :created_by_id)
    add_column :quotes, :updated_by_id, :integer unless column_exists?(:quotes, :updated_by_id)
    add_index :quotes, :created_by_id unless index_exists?(:quotes, :created_by_id)
    add_index :quotes, :updated_by_id unless index_exists?(:quotes, :updated_by_id)
    unless foreign_key_exists?(:quotes, :users, column: :created_by_id)
      add_foreign_key :quotes, :users, column: :created_by_id
    end
    unless foreign_key_exists?(:quotes, :users, column: :updated_by_id)
      add_foreign_key :quotes, :users, column: :updated_by_id
    end
  end

  def down
    remove_foreign_key :quotes, column: :updated_by_id if foreign_key_exists?(:quotes, :users, column: :updated_by_id)
    remove_foreign_key :quotes, column: :created_by_id if foreign_key_exists?(:quotes, :users, column: :created_by_id)
    remove_index :quotes, :updated_by_id if index_exists?(:quotes, :updated_by_id)
    remove_index :quotes, :created_by_id if index_exists?(:quotes, :created_by_id)
    remove_column :quotes, :updated_by_id if column_exists?(:quotes, :updated_by_id)
    remove_column :quotes, :created_by_id if column_exists?(:quotes, :created_by_id)
  end
end
