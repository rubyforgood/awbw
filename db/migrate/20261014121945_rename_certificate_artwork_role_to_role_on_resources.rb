class RenameCertificateArtworkRoleToRoleOnResources < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:resources, :certificate_artwork_role)
    rename_column :resources, :certificate_artwork_role, :role
  end

  def down
    return unless column_exists?(:resources, :role)
    rename_column :resources, :role, :certificate_artwork_role
  end
end
