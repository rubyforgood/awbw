class AddIsPrimaryToCategorizableItems < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:categorizable_items, :is_primary)

    add_column :categorizable_items, :is_primary, :boolean, default: false, null: false
  end

  def down
    remove_column :categorizable_items, :is_primary, if_exists: true
  end
end
