class AddInactiveToSectorableItems < ActiveRecord::Migration
  def change
    add_column :sectorable_items, :inactive, :boolean, default: true
  end
end
