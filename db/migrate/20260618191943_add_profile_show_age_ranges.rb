class AddProfileShowAgeRanges < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :profile_show_age_ranges, :boolean, default: true, null: false unless column_exists?(:people, :profile_show_age_ranges)
    add_column :organizations, :profile_show_age_ranges, :boolean, default: true, null: false unless column_exists?(:organizations, :profile_show_age_ranges)
  end

  def down
    remove_column :people, :profile_show_age_ranges, if_exists: true
    remove_column :organizations, :profile_show_age_ranges, if_exists: true
  end
end
