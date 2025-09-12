class AddLegacyIdToPermissions < ActiveRecord::Migration
  def change
    add_column :permissions, :legacy_id, :integer
  end
end
