class RemoveUserIdFromAffiliations < ActiveRecord::Migration[8.1]
  # Vestigial column: never backed by an association, and every populated row's
  # user already resolves to the affiliation's own person (users.person_id =
  # affiliations.person_id for all 1,537 non-null rows, 0 mismatches). The person
  # link is the source of truth, so user_id carries no unique information.
  def up
    remove_foreign_key :affiliations, :users, if_exists: true
    remove_index :affiliations, :user_id, if_exists: true
    remove_column :affiliations, :user_id, if_exists: true
  end

  def down
    add_column :affiliations, :user_id, :integer unless column_exists?(:affiliations, :user_id)
    unless index_exists?(:affiliations, :user_id, name: "index_affiliations_on_user_id")
      add_index :affiliations, :user_id, name: "index_affiliations_on_user_id"
    end
    unless foreign_key_exists?(:affiliations, :users)
      add_foreign_key :affiliations, :users
    end
  end
end
