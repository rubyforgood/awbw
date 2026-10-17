class PointSettingsAtIssuerAddresses < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:settings, :return_address_id)
      add_reference :settings, :return_address, null: true
    end
    unless column_exists?(:settings, :remittance_address_id)
      add_reference :settings, :remittance_address, null: true
    end
    unless foreign_key_exists?(:settings, column: :return_address_id)
      add_foreign_key :settings, :addresses, column: :return_address_id, on_delete: :nullify
    end
    unless foreign_key_exists?(:settings, column: :remittance_address_id)
      add_foreign_key :settings, :addresses, column: :remittance_address_id, on_delete: :nullify
    end
    remove_column :settings, :organization_address if column_exists?(:settings, :organization_address)
    remove_column :settings, :remittance_address if column_exists?(:settings, :remittance_address)
  end

  def down
    add_column :settings, :organization_address, :text unless column_exists?(:settings, :organization_address)
    add_column :settings, :remittance_address, :text unless column_exists?(:settings, :remittance_address)
    remove_foreign_key :settings, column: :return_address_id if foreign_key_exists?(:settings, column: :return_address_id)
    remove_foreign_key :settings, column: :remittance_address_id if foreign_key_exists?(:settings, column: :remittance_address_id)
    remove_reference :settings, :return_address if column_exists?(:settings, :return_address_id)
    remove_reference :settings, :remittance_address if column_exists?(:settings, :remittance_address_id)
  end
end
