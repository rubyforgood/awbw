class AddProposedValuesToProfileChangeRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_change_requests, :proposed_title, :string
    add_column :profile_change_requests, :proposed_start_date, :date
    add_column :profile_change_requests, :proposed_end_date, :date
    add_column :profile_change_requests, :proposed_organization_name, :string
  end
end
