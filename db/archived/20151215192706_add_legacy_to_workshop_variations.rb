class AddLegacyToWorkshopVariations < ActiveRecord::Migration
  def change
    add_column :workshop_variations, :legacy, :boolean, default: false
  end
end
