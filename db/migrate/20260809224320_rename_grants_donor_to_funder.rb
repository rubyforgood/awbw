class RenameGrantsDonorToFunder < ActiveRecord::Migration[8.0]
  def up
    rename_column :grants, :donor_id, :funder_id if column_exists?(:grants, :donor_id)
    rename_column :grants, :donor_type, :funder_type if column_exists?(:grants, :donor_type)
    if index_exists?(:grants, [ :funder_type, :funder_id ], name: "index_grants_on_donor")
      rename_index :grants, "index_grants_on_donor", "index_grants_on_funder"
    end
  end

  def down
    rename_column :grants, :funder_id, :donor_id if column_exists?(:grants, :funder_id)
    rename_column :grants, :funder_type, :donor_type if column_exists?(:grants, :funder_type)
    if index_exists?(:grants, [ :donor_type, :donor_id ], name: "index_grants_on_funder")
      rename_index :grants, "index_grants_on_funder", "index_grants_on_donor"
    end
  end
end
