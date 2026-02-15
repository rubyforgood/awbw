class RenameIsPrimaryToPrimary < ActiveRecord::Migration[8.1]
  def change
    rename_column :contact_methods, :is_primary, :primary
    rename_column :addresses, :is_primary, :primary
  end
end
