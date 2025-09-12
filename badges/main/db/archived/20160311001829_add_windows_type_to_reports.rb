class AddWindowsTypeToReports < ActiveRecord::Migration
  def change
    add_reference :reports, :windows_type, index: true
    add_foreign_key :reports, :windows_types
  end
end
