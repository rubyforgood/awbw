class AddProfileShowAgeRangesToPeople < ActiveRecord::Migration[8.0]
  # Mirrors profile_show_sectors: a per-person toggle for showing their age
  # ranges on public surfaces (profile, staff roster). Defaults true to preserve
  # today's always-shown behavior.
  def up
    return if column_exists?(:people, :profile_show_age_ranges)
    add_column :people, :profile_show_age_ranges, :boolean, default: true, null: false
  end

  def down
    remove_column :people, :profile_show_age_ranges, if_exists: true
  end
end
