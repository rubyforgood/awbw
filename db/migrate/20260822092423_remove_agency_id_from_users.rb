class RemoveAgencyIdFromUsers < ActiveRecord::Migration[8.1]
  # Legacy column carried over from the old schema. Prod holds no values (all NULL),
  # and its only remaining readers are being cut over in the same change. Second and
  # final half of #414 (the affiliations half shipped in #2305).
  def up
    remove_foreign_key :users, column: :agency_id, if_exists: true
    remove_index :users, :agency_id, if_exists: true
    remove_column :users, :agency_id, if_exists: true
  end

  def down
    add_column :users, :agency_id, :integer unless column_exists?(:users, :agency_id)
    add_index :users, :agency_id unless index_exists?(:users, :agency_id)
    unless foreign_key_exists?(:users, column: :agency_id)
      add_foreign_key :users, :organizations, column: :agency_id
    end
  end
end
