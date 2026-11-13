class RequirePeopleDisplayNamePreference < ActiveRecord::Migration[8.1]
  # The default these rows already displayed as; frozen here so the migration doesn't follow later changes.
  FILL_VALUE = "first_name_last_initial"

  def up
    execute <<~SQL.squish
      UPDATE people SET display_name_preference = '#{FILL_VALUE}'
      WHERE display_name_preference IS NULL OR TRIM(display_name_preference) = ''
    SQL
    change_column_null :people, :display_name_preference, false
  end

  def down
    change_column_null :people, :display_name_preference, true
  end
end
