class RemoveLeaderIdFromAgencies < ActiveRecord::Migration
  def change
    remove_column :agencies, :leader_id
  end
end
