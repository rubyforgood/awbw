class AddProposedOrganizationAddressToProfileChangeRequests < ActiveRecord::Migration[8.1]
  def up
    add_reference :profile_change_requests, :proposed_organization_address, null: true,
                                                                             foreign_key: { to_table: :addresses, on_delete: :nullify }
  end

  def down
    remove_foreign_key :profile_change_requests, column: :proposed_organization_address_id, if_exists: true
    remove_reference :profile_change_requests, :proposed_organization_address, if_exists: true
  end
end
