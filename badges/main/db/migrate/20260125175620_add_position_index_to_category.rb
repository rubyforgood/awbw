class AddPositionIndexToCategory < ActiveRecord::Migration[8.1]
  def change
    add_index :categories, [ :metadatum_id, :position ], unique: true
  end
end
