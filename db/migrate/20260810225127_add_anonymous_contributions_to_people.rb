class AddAnonymousContributionsToPeople < ActiveRecord::Migration[7.2]
  def up
    add_column :people, :anonymous_contributions, :boolean, default: false, null: false unless column_exists?(:people, :anonymous_contributions)
  end

  def down
    remove_column :people, :anonymous_contributions, if_exists: true
  end
end
