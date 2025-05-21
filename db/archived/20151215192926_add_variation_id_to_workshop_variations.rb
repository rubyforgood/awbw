class AddVariationIdToWorkshopVariations < ActiveRecord::Migration
  def change
    add_column :workshop_variations, :variation_id, :integer
  end
end


