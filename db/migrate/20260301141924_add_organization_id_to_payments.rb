class AddOrganizationIdToPayments < ActiveRecord::Migration[8.1]
  def change
    remove_column :payments, :organization_id, if_exists: true
    add_reference :payments, :organization, type: :integer, null: true, foreign_key: true
  end
end
