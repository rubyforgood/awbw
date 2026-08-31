class RemoveVariationIdFromWorkshopVariations < ActiveRecord::Migration[8.1]
  def up
    remove_column :workshop_variations, :variation_id, if_exists: true
  end

  def down
    add_column :workshop_variations, :variation_id, :integer unless column_exists?(:workshop_variations, :variation_id)
  end
end
