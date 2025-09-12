class AddShortNameToWindowsTypes < ActiveRecord::Migration
  def change
    add_column :windows_types, :short_name, :string
  end
end
