class AddPositionIndexToCategory < ActiveRecord::Migration[8.1]
  def change
    Category.heal_position_column!(name: :desc)
    add_index :categories, [ :metadatum_id, :position ], unique: true
  end
end
