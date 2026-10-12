class AddCertificateRoleToResources < ActiveRecord::Migration[8.0]
  def up
    add_column :resources, :certificate_role, :string unless column_exists?(:resources, :certificate_role)
    # Unique so at most one Resource is connected to each certificate slot; MySQL
    # allows many NULLs, so unconnected resources are unconstrained.
    add_index :resources, :certificate_role, unique: true unless index_exists?(:resources, :certificate_role)
  end

  def down
    remove_index :resources, :certificate_role, if_exists: true
    remove_column :resources, :certificate_role, if_exists: true
  end
end
