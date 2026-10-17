class AddProposedWorkAddressToProfileChangeRequests < ActiveRecord::Migration[8.1]
  def up
    add_reference :profile_change_requests, :proposed_organization_address, null: true,
                                                                             foreign_key: { to_table: :addresses, on_delete: :nullify }
    add_column :profile_change_requests, :proposed_street_address, :string
    add_column :profile_change_requests, :proposed_city, :string
    add_column :profile_change_requests, :proposed_state, :string
    add_column :profile_change_requests, :proposed_zip_code, :string
  end

  def down
    remove_column :profile_change_requests, :proposed_zip_code, if_exists: true
    remove_column :profile_change_requests, :proposed_state, if_exists: true
    remove_column :profile_change_requests, :proposed_city, if_exists: true
    remove_column :profile_change_requests, :proposed_street_address, if_exists: true
    remove_foreign_key :profile_change_requests, column: :proposed_organization_address_id, if_exists: true
    remove_reference :profile_change_requests, :proposed_organization_address, if_exists: true
  end
end
