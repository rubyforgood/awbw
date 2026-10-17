class AddCertificateArtworkRoleToResources < ActiveRecord::Migration[8.0]
  def up
    add_column :resources, :certificate_artwork_role, :string unless column_exists?(:resources, :certificate_artwork_role)
    # One resource per certificate slot: unique so a role can't be claimed by two
    # resources. Unconnected resources keep it NULL, and MySQL leaves NULLs out of
    # a unique index, so the many NULLs never collide.
    add_index :resources, :certificate_artwork_role, unique: true unless index_exists?(:resources, :certificate_artwork_role)
  end

  def down
    remove_index :resources, :certificate_artwork_role, if_exists: true
    remove_column :resources, :certificate_artwork_role, if_exists: true
  end
end
