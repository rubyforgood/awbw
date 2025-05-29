class AddCodeToWorkshopVariations < ActiveRecord::Migration[4.2]
  def change
    add_column :workshop_variations, :code, :text
    add_column :workshop_variations, :inactive, :boolean, default: true
    remove_column :workshop_variations, :variation_id
  end
end
