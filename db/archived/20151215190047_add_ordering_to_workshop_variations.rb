class AddOrderingToWorkshopVariations < ActiveRecord::Migration
  def change
    add_column :workshop_variations, :ordering, :integer
  end
end
