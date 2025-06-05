class AddOrderingToWorkshopVariations < ActiveRecord::Migration[4.2]
  def change
    add_column :workshop_variations, :ordering, :integer
  end
end
