class AddVariationIdToWorkshopVariations < ActiveRecord::Migration[4.2]
  def change
    add_column :workshop_variations, :variation_id, :integer
  end
end


