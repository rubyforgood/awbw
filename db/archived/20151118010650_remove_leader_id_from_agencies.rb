class RemoveLeaderIdFromAgencies < ActiveRecord::Migration[4.2]
  def change
    remove_column :agencies, :leader_id
  end
end
