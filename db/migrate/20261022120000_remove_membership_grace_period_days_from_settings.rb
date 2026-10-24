class RemoveMembershipGracePeriodDaysFromSettings < ActiveRecord::Migration[8.1]
  # The membership grace window was dropped, so the setting no longer means anything.
  # Guarded because a fresh database creates the column in the same run.
  def up
    remove_column :settings, :membership_grace_period_days if column_exists?(:settings, :membership_grace_period_days)
  end

  def down
    add_column :settings, :membership_grace_period_days, :integer unless column_exists?(:settings, :membership_grace_period_days)
  end
end
