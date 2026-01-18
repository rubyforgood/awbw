class RenameOrderingToPositionOnWorkshopVariations < ActiveRecord::Migration[8.1]
  def change
    rename_column :workshop_variations, :ordering, :position
  end
end
