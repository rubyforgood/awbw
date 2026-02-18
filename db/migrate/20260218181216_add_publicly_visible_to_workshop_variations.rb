class AddPubliclyVisibleToWorkshopVariations < ActiveRecord::Migration[8.1]
  def change
    add_column :workshop_variations, :publicly_visible, :boolean, default: false, null: false
  end
end
