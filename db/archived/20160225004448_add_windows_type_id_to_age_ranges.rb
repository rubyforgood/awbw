class AddWindowsTypeIdToAgeRanges < ActiveRecord::Migration[4.2]
  def change
    add_reference :age_ranges, :windows_type, index: true
    add_foreign_key :age_ranges, :windows_types
  end
end
