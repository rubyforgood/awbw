class AddLegacyIdToPermissions < ActiveRecord::Migration[4.2]
  def change
    add_column :permissions, :legacy_id, :integer
  end
end
