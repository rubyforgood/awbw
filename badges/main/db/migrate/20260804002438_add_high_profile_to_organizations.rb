class AddHighProfileToOrganizations < ActiveRecord::Migration[8.0]
  # Internal flag marking an organization as high-profile — surfaced with a star
  # next to the org name on list pages (event dashboard, background reporting) so
  # staff can spot notable programs at a glance. Defaults false.
  def up
    return if column_exists?(:organizations, :high_profile)
    add_column :organizations, :high_profile, :boolean, default: false, null: false
  end

  def down
    remove_column :organizations, :high_profile, if_exists: true
  end
end
