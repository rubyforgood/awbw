class AddLegacyToWorkshopVariations < ActiveRecord::Migration[4.2]
  def change
    add_column :workshop_variations, :legacy, :boolean, default: false
  end
end
