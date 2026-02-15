# frozen_string_literal: true

class CopyTimeZoneFromUsersToPeople < ActiveRecord::Migration[8.1]
  def up
    # Copy time_zone from users to people where user has a person
    # Using raw SQL for efficiency while being database-agnostic
    if ActiveRecord::Base.connection.adapter_name.downcase.include?("mysql")
      execute <<-SQL.squish
        UPDATE people
        INNER JOIN users ON users.person_id = people.id
        SET people.time_zone = users.time_zone
        WHERE users.time_zone IS NOT NULL
      SQL
    else
      # PostgreSQL syntax
      execute <<-SQL.squish
        UPDATE people
        SET time_zone = users.time_zone
        FROM users
        WHERE users.person_id = people.id
        AND users.time_zone IS NOT NULL
      SQL
    end
  end

  def down
    # No need to reverse this data migration
  end
end
