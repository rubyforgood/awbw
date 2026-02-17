class AddNotNullConstraintsToAffiliations < ActiveRecord::Migration[8.1]
  def up
    # Clean up any orphaned records before adding constraints
    Affiliation.where(organization_id: nil).destroy_all
    Affiliation.where(person_id: nil).destroy_all

    change_column_null :affiliations, :organization_id, false
    change_column_null :affiliations, :person_id, false

    # Fix column type so foreign key can be added (people.id is int, not bigint)
    change_column :affiliations, :person_id, :integer, null: false

    unless foreign_key_exists?(:affiliations, :people, column: :person_id)
      add_foreign_key :affiliations, :people, column: :person_id
    end
  end

  def down
    change_column_null :affiliations, :organization_id, true
    change_column_null :affiliations, :person_id, true

    if foreign_key_exists?(:affiliations, :people, column: :person_id)
      remove_foreign_key :affiliations, :people, column: :person_id
    end

    change_column :affiliations, :person_id, :bigint
  end
end
