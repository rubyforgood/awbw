class AddLegacyIdToWindowsTypes < ActiveRecord::Migration[4.2]
  def change
    add_column :windows_types, :legacy_id, :integer
  end
end
