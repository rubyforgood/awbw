class AddShortNameToWindowsTypes < ActiveRecord::Migration[4.2]
  def change
    add_column :windows_types, :short_name, :string
  end
end
