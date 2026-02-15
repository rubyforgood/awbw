class AddNotNullConstraintsToOrganizationPeople < ActiveRecord::Migration[8.1]
  def up
    # Clean up any orphaned records before adding constraints
    OrganizationPerson.where(organization_id: nil).destroy_all
    OrganizationPerson.where(person_id: nil).destroy_all

    change_column_null :organization_people, :organization_id, false
    change_column_null :organization_people, :person_id, false

    # Fix column type so foreign key can be added (people.id is int, not bigint)
    change_column :organization_people, :person_id, :integer, null: false

    unless foreign_key_exists?(:organization_people, :people, column: :person_id)
      add_foreign_key :organization_people, :people, column: :person_id
    end
  end

  def down
    change_column_null :organization_people, :organization_id, true
    change_column_null :organization_people, :person_id, true

    if foreign_key_exists?(:organization_people, :people, column: :person_id)
      remove_foreign_key :organization_people, :people, column: :person_id
    end

    change_column :organization_people, :person_id, :bigint
  end
end
