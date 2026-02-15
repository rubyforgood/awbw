# frozen_string_literal: true

class CopyTimeZoneFromUsersToPeople < ActiveRecord::Migration[8.1]
  def up
    # Copy time_zone from users to people where user has a person
    execute <<-SQL
      UPDATE people
      INNER JOIN users ON users.person_id = people.id
      SET people.time_zone = users.time_zone
      WHERE users.time_zone IS NOT NULL
    SQL
  end

  def down
    # No need to reverse this data migration
  end
end
