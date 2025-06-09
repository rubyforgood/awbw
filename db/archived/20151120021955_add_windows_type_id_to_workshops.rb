class AddWindowsTypeIdToWorkshops < ActiveRecord::Migration
  def change
    add_reference :workshops, :windows_type, index: true
    add_foreign_key :workshops, :windows_types
  end
end
