class AddLegacyIdToWindowsTypes < ActiveRecord::Migration
  def change
    add_column :windows_types, :legacy_id, :integer
  end
end
