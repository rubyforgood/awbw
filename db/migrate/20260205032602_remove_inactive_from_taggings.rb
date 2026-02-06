class RemoveInactiveFromTaggings < ActiveRecord::Migration[8.1]
  def change
    # Remove inactive column from sectorable_items and categorizable_items bc they should either exist or not

    if column_exists?(:sectorable_items, :inactive)
      remove_column :sectorable_items, :inactive
    end
    if column_exists?(:categorizable_items, :inactive)
      remove_column :categorizable_items, :inactive
    end
  end
end
