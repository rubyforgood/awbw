class AddLeaderToSectorableItem < ActiveRecord::Migration[8.1]
  def change
    add_column :sectorable_items, :is_leader, :boolean, default: false, null: false
  end
end
