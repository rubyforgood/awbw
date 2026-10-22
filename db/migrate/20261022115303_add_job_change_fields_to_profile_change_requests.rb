class AddJobChangeFieldsToProfileChangeRequests < ActiveRecord::Migration[8.1]
  def up
    add_column :profile_change_requests, :leaving_job, :boolean, default: false, null: false unless column_exists?(:profile_change_requests, :leaving_job)
    add_column :profile_change_requests, :left_organization_ids, :json unless column_exists?(:profile_change_requests, :left_organization_ids)
  end

  def down
    remove_column :profile_change_requests, :left_organization_ids if column_exists?(:profile_change_requests, :left_organization_ids)
    remove_column :profile_change_requests, :leaving_job if column_exists?(:profile_change_requests, :leaving_job)
  end
end
