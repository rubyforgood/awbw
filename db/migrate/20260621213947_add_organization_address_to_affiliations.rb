class AddOrganizationAddressToAffiliations < ActiveRecord::Migration[8.1]
  def up
    add_column :affiliations, :organization_address_id, :bigint
    add_index :affiliations, :organization_address_id
    add_foreign_key :affiliations, :addresses, column: :organization_address_id, on_delete: :nullify
  end

  def down
    remove_foreign_key :affiliations, column: :organization_address_id if foreign_key_exists?(:affiliations, column: :organization_address_id)
    remove_index :affiliations, :organization_address_id if index_exists?(:affiliations, :organization_address_id)
    remove_column :affiliations, :organization_address_id if column_exists?(:affiliations, :organization_address_id)
  end
end
