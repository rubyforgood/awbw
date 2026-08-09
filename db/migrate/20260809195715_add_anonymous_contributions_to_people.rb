class AddAnonymousContributionsToPeople < ActiveRecord::Migration[8.1]
  # Profile preference set from a post-event survey question: keep all shared content
  # anonymous. Stored now; enforcement across content display is a later change. Nullable
  # so "not answered" (nil) stays distinct from an explicit choice.
  def up
    return if column_exists?(:people, :anonymous_contributions)
    add_column :people, :anonymous_contributions, :boolean
  end

  def down
    remove_column :people, :anonymous_contributions, if_exists: true
  end
end
