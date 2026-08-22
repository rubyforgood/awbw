class RemoveOrganizationAgencyIdFromAffiliations < ActiveRecord::Migration[8.1]
  # Dead column: no model association, scope, or code ever read or wrote it. It
  # rode along from the legacy schema and was never wired up.
  def up
    remove_foreign_key :affiliations, column: :organization_agency_id, if_exists: true
    remove_index :affiliations, :organization_agency_id, if_exists: true
    remove_column :affiliations, :organization_agency_id, if_exists: true
  end

  def down
    add_column :affiliations, :organization_agency_id, :integer unless column_exists?(:affiliations, :organization_agency_id)
    add_index :affiliations, :organization_agency_id unless index_exists?(:affiliations, :organization_agency_id)
    unless foreign_key_exists?(:affiliations, column: :organization_agency_id)
      add_foreign_key :affiliations, :organizations, column: :organization_agency_id
    end
  end
end
