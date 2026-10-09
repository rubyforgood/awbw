class AddUniqueNameAndEmailIndexToPeople < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_people_on_name_and_email"

  def up
    duplicates = select_rows(<<~SQL)
      SELECT first_name, last_name, email, GROUP_CONCAT(id ORDER BY id) AS person_ids
      FROM people
      WHERE email IS NOT NULL
      GROUP BY first_name, last_name, email
      HAVING COUNT(*) > 1
    SQL

    if duplicates.any?
      groups = duplicates.map { |first, last, email, ids| "#{first} #{last} <#{email}> (people #{ids})" }
      raise ActiveRecord::MigrationError,
        "Merge these duplicate people at /people/dedupe_index before adding #{INDEX_NAME}:\n  #{groups.join("\n  ")}"
    end

    add_index :people, %i[first_name last_name email], unique: true, name: INDEX_NAME
  end

  def down
    remove_index :people, name: INDEX_NAME, if_exists: true
  end
end
