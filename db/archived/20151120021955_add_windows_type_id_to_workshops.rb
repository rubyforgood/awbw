class AddWindowsTypeIdToWorkshops < ActiveRecord::Migration[4.2]
  def change
    add_reference :workshops, :windows_type, index: true
    add_foreign_key :workshops, :windows_types
  end
end
