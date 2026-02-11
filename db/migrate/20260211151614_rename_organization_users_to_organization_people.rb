class RenameOrganizationUsersToOrganizationPeople < ActiveRecord::Migration[8.1]
  def up
    rename_table :organization_users, :organization_people

    # Add person_id column before removing user_id
    add_column :organization_people, :person_id, :integer

    # Update person_id with the person_id from users table
    execute <<-SQL
      UPDATE organization_people#{' '}
      SET person_id = (
        SELECT person_id#{' '}
        FROM users#{' '}
        WHERE users.id = organization_people.user_id
      )
    SQL

    # Remove old user_id column and index
    remove_index :organization_people, name: :index_organization_users_on_user_id if index_exists?(:organization_people, :user_id)
    remove_column :organization_people, :user_id

    # Add index for person_id
    add_index :organization_people, :person_id, name: :index_organization_people_on_person_id
  end

  def down
    # Add user_id column back
    add_column :organization_people, :user_id, :integer

    # Update user_id with the id from users table where person_id matches
    execute <<-SQL
      UPDATE organization_people#{' '}
      SET user_id = (
        SELECT id#{' '}
        FROM users#{' '}
        WHERE users.person_id = organization_people.person_id
      )
    SQL

    # Remove person_id column and index
    remove_index :organization_people, name: :index_organization_people_on_person_id if index_exists?(:organization_people, :person_id)
    remove_column :organization_people, :person_id

    # Add index for user_id
    add_index :organization_people, :user_id, name: :index_organization_users_on_user_id

    # Rename table back
    rename_table :organization_people, :organization_users
  end
end
