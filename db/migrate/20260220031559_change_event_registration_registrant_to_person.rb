class ChangeEventRegistrationRegistrantToPerson < ActiveRecord::Migration[8.0]
  def up
    # 1. Upsize people.id from int to bigint (and all FK columns that reference it)
    remove_foreign_key :affiliations, :people
    remove_foreign_key :users, :people
    remove_foreign_key :stories, column: :spotlighted_facilitator_id

    change_column :people, :id, :bigint, auto_increment: true
    change_column :affiliations, :person_id, :bigint, null: false
    change_column :users, :person_id, :bigint
    change_column :stories, :spotlighted_facilitator_id, :bigint

    add_foreign_key :affiliations, :people
    add_foreign_key :users, :people
    add_foreign_key :stories, :people, column: :spotlighted_facilitator_id

    # 2. Add person_id column
    unless column_exists?(:event_registrations, :person_id)
      add_column :event_registrations, :person_id, :bigint
    end

    # 3. Backfill: map user IDs to person IDs
    execute <<~SQL
      UPDATE event_registrations
      SET person_id = (
        SELECT person_id FROM users WHERE users.id = event_registrations.registrant_id
      )
    SQL

    # 4. Remove old column, indexes, and FK
    if foreign_key_exists?(:event_registrations, column: :registrant_id)
      remove_foreign_key :event_registrations, column: :registrant_id
    end
    remove_index :event_registrations, :registrant_id, if_exists: true
    remove_index :event_registrations, [:registrant_id, :event_id], if_exists: true
    remove_column :event_registrations, :registrant_id, if_exists: true

    # 5. Rename person_id to registrant_id
    rename_column :event_registrations, :person_id, :registrant_id

    # 6. Add constraints and indexes
    change_column_null :event_registrations, :registrant_id, false
    add_index :event_registrations, :registrant_id
    add_index :event_registrations, [:registrant_id, :event_id], unique: true
    add_foreign_key :event_registrations, :people, column: :registrant_id
  end

  def down
    # 1. Remove event_registrations FK and indexes
    remove_foreign_key :event_registrations, column: :registrant_id
    remove_index :event_registrations, [:registrant_id, :event_id], if_exists: true
    remove_index :event_registrations, :registrant_id, if_exists: true

    # 2. Add user_id column
    add_column :event_registrations, :user_id, :integer

    # 3. Backfill: map person IDs back to user IDs
    execute <<~SQL
      UPDATE event_registrations
      SET user_id = (
        SELECT users.id FROM users WHERE users.person_id = event_registrations.registrant_id
      )
    SQL

    # 4. Remove registrant_id, rename user_id
    remove_column :event_registrations, :registrant_id
    rename_column :event_registrations, :user_id, :registrant_id

    # 5. Restore original constraints
    add_index :event_registrations, :registrant_id
    add_index :event_registrations, [:registrant_id, :event_id], unique: true
    add_foreign_key :event_registrations, :users, column: :registrant_id

    # 6. Downsize people.id back to int
    remove_foreign_key :affiliations, :people
    remove_foreign_key :users, :people
    remove_foreign_key :stories, column: :spotlighted_facilitator_id

    change_column :stories, :spotlighted_facilitator_id, :integer
    change_column :users, :person_id, :integer
    change_column :affiliations, :person_id, :integer, null: false
    change_column :people, :id, :integer, auto_increment: true

    add_foreign_key :affiliations, :people
    add_foreign_key :users, :people
    add_foreign_key :stories, :people, column: :spotlighted_facilitator_id
  end
end
