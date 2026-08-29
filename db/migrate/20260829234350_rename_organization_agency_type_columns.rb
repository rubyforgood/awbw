class RenameOrganizationAgencyTypeColumns < ActiveRecord::Migration[8.1]
  def up
    rename_column :organizations, :agency_type, :organization_type if column_exists?(:organizations, :agency_type)
    rename_column :organizations, :agency_type_other, :organization_type_other if column_exists?(:organizations, :agency_type_other)
  end

  def down
    rename_column :organizations, :organization_type, :agency_type if column_exists?(:organizations, :organization_type)
    rename_column :organizations, :organization_type_other, :agency_type_other if column_exists?(:organizations, :organization_type_other)
  end
end
