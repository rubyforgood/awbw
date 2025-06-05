class AddInactiveToSectorableItems < ActiveRecord::Migration[4.2]
  def change
    add_column :sectorable_items, :inactive, :boolean, default: true
  end
end
