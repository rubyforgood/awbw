class AddNameToWorkshopVariations < ActiveRecord::Migration[4.2]
  def change
    add_column :workshop_variations, :name, :string
  end
end
