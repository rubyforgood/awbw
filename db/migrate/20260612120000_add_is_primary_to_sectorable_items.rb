class AddIsPrimaryToSectorableItems < ActiveRecord::Migration[8.1]
  def up
    add_column :sectorable_items, :is_primary, :boolean, default: false, null: false
  end

  def down
    remove_column :sectorable_items, :is_primary, if_exists: true
  end
end
