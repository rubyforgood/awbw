class ChangeOrganizationsIdToInteger < ActiveRecord::Migration[8.1]
  def up
    # Drop foreign keys first (skip if already removed)
    remove_foreign_key :addresses, :organizations rescue nil
    remove_foreign_key :facilitator_organizations, :organizations rescue nil

    # Change column types
    change_column :organizations, :id, :integer
    change_column :addresses, :organization_id, :integer
    change_column :facilitator_organizations, :organization_id, :integer

    # Re-add foreign keys
    add_foreign_key :addresses, :organizations
    add_foreign_key :facilitator_organizations, :organizations
  end

  def down
    # Drop foreign keys first
    remove_foreign_key :addresses, :organizations rescue nil
    remove_foreign_key :facilitator_organizations, :organizations rescue nil

    # Revert column types back to bigint (Rails default)
    change_column :organizations, :id, :bigint
    change_column :addresses, :organization_id, :bigint
    change_column :facilitator_organizations, :organization_id, :bigint

    # Re-add foreign keys
    add_foreign_key :addresses, :organizations
    add_foreign_key :facilitator_organizations, :organizations
  end
end
