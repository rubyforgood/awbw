class AllowSeveralInvoiceAddresses < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_addresses_on_addressable_and_invoice_role".freeze
  INDEX_COLUMNS = [ :addressable_type, :addressable_id, :invoice_address ].freeze

  # An owner may mark any number of its addresses for invoices, so the index that
  # capped it at one becomes a plain lookup index.
  def up
    return unless index_exists?(:addresses, INDEX_COLUMNS, name: INDEX_NAME, unique: true)

    remove_index :addresses, name: INDEX_NAME
    add_index :addresses, INDEX_COLUMNS, name: INDEX_NAME
  end

  # Restoring the cap needs one flagged address per owner, and the unflagged ones
  # back to NULL: MySQL counts every `false` as a duplicate, every NULL as distinct.
  def down
    return if index_exists?(:addresses, INDEX_COLUMNS, name: INDEX_NAME, unique: true)

    remove_index :addresses, name: INDEX_NAME if index_exists?(:addresses, INDEX_COLUMNS, name: INDEX_NAME)
    execute "UPDATE addresses SET invoice_address = NULL WHERE invoice_address = FALSE"
    execute <<~SQL.squish
      UPDATE addresses
        JOIN (
          SELECT addressable_type, addressable_id, MIN(id) AS keeper_id
          FROM addresses WHERE invoice_address = TRUE
          GROUP BY addressable_type, addressable_id
        ) keepers
        ON keepers.addressable_type = addresses.addressable_type
          AND keepers.addressable_id = addresses.addressable_id
      SET addresses.invoice_address = NULL
      WHERE addresses.invoice_address = TRUE AND addresses.id <> keepers.keeper_id
    SQL
    add_index :addresses, INDEX_COLUMNS, unique: true, name: INDEX_NAME
  end
end
