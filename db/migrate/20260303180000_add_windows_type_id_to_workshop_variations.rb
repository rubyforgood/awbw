class AddWindowsTypeIdToWorkshopVariations < ActiveRecord::Migration[8.0]
  def change
    add_reference :workshop_variations, :windows_type, type: :integer, foreign_key: true, null: true
  end
end
