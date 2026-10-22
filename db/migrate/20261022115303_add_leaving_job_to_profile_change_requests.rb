class AddLeavingJobToProfileChangeRequests < ActiveRecord::Migration[8.1]
  def up
    add_column :profile_change_requests, :leaving_job, :boolean, default: false, null: false unless column_exists?(:profile_change_requests, :leaving_job)
  end

  def down
    remove_column :profile_change_requests, :leaving_job if column_exists?(:profile_change_requests, :leaving_job)
  end
end
