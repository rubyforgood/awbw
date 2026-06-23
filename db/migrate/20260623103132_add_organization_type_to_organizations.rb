class AddOrganizationTypeToOrganizations < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:organizations, :organization_type_id)

    add_reference :organizations, :organization_type, foreign_key: true, null: true, index: true
  end

  def down
    remove_reference :organizations, :organization_type, foreign_key: true, if_exists: true
  end
end
