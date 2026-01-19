class AddUniqueIndexesToTaggings < ActiveRecord::Migration[7.1]
  def change
    # Add unique index to sectorable_items to prevent duplicate taggings
    add_index :sectorable_items, 
              [:sector_id, :sectorable_type, :sectorable_id], 
              unique: true, 
              name: "index_sectorable_items_uniqueness"
    
    # Add unique index to categorizable_items to prevent duplicate taggings
    add_index :categorizable_items, 
              [:category_id, :categorizable_type, :categorizable_id], 
              unique: true, 
              name: "index_categorizable_items_uniqueness"
  end
end
