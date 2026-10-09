class AddAddressRolesAndOrgTaxId < ActiveRecord::Migration[8.1]
  # The role flags are nullable and only ever store `true`. MySQL has no partial
  # indexes, but it allows unlimited NULLs in a unique index, so a plain unique
  # index on the nullable column enforces "at most one" per owner.
  def up
    add_column :organizations, :tax_id, :string unless column_exists?(:organizations, :tax_id)

    add_column :addresses, :invoice_address, :boolean unless column_exists?(:addresses, :invoice_address)

    unless index_exists?(:addresses, [ :addressable_type, :addressable_id, :invoice_address ])
      add_index :addresses, [ :addressable_type, :addressable_id, :invoice_address ],
                unique: true, name: "index_addresses_on_addressable_and_invoice_role"
    end
  end

  def down
    remove_index :addresses, name: "index_addresses_on_addressable_and_invoice_role" if index_exists?(:addresses, [ :addressable_type, :addressable_id, :invoice_address ])
    remove_column :addresses, :invoice_address, if_exists: true
    remove_column :organizations, :tax_id, if_exists: true
  end
end
