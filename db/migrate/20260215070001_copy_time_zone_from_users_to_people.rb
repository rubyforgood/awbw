# frozen_string_literal: true

class CopyTimeZoneFromUsersToPeople < ActiveRecord::Migration[8.1]
  def up
    # Copy time_zone from users to people where user has a person
    # Using ActiveRecord for database compatibility
    User.where.not(person_id: nil).where.not(time_zone: nil).find_each do |user|
      Person.where(id: user.person_id).update_all(time_zone: user.time_zone)
    end
  end

  def down
    # No need to reverse this data migration
  end
end
