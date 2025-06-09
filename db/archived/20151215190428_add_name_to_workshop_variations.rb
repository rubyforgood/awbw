class AddNameToWorkshopVariations < ActiveRecord::Migration
  def change
    add_column :workshop_variations, :name, :string
  end
end
