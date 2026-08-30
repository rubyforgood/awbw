class AddUserStampsToNotifications < ActiveRecord::Migration[8.1]
  # Notifications keep their own sender_id (who a communication is from); these add
  # the standard created_by/updated_by so the record is attributable like every other,
  # in addition to sender. UserStampable fills them going forward.
  def up
    add_column :notifications, :created_by_id, :integer, null: true unless column_exists?(:notifications, :created_by_id)
    add_column :notifications, :updated_by_id, :integer, null: true unless column_exists?(:notifications, :updated_by_id)
    add_index :notifications, :created_by_id unless index_exists?(:notifications, :created_by_id)
    add_index :notifications, :updated_by_id unless index_exists?(:notifications, :updated_by_id)
    add_foreign_key :notifications, :users, column: :created_by_id unless foreign_key_exists?(:notifications, :users, column: :created_by_id)
    add_foreign_key :notifications, :users, column: :updated_by_id unless foreign_key_exists?(:notifications, :users, column: :updated_by_id)
  end

  def down
    remove_foreign_key :notifications, :users, column: :created_by_id if foreign_key_exists?(:notifications, :users, column: :created_by_id)
    remove_foreign_key :notifications, :users, column: :updated_by_id if foreign_key_exists?(:notifications, :users, column: :updated_by_id)
    remove_index :notifications, :created_by_id if index_exists?(:notifications, :created_by_id)
    remove_index :notifications, :updated_by_id if index_exists?(:notifications, :updated_by_id)
    remove_column :notifications, :created_by_id if column_exists?(:notifications, :created_by_id)
    remove_column :notifications, :updated_by_id if column_exists?(:notifications, :updated_by_id)
  end
end
