class AddProfileShowAgeRangesToOrganizations < ActiveRecord::Migration[8.0]
  # Parity with people.profile_show_age_ranges (and organizations.profile_show_sectors):
  # a per-organization toggle for showing age ranges on the public profile.
  # Defaults true to preserve today's always-shown behavior.
  def up
    return if column_exists?(:organizations, :profile_show_age_ranges)
    add_column :organizations, :profile_show_age_ranges, :boolean, default: true, null: false
  end

  def down
    remove_column :organizations, :profile_show_age_ranges, if_exists: true
  end
end
