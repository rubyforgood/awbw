class AddMembershipAutopayWindowDaysToSettings < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:settings, :membership_autopay_window_days)

    add_column :settings, :membership_autopay_window_days, :integer
  end

  def down
    remove_column :settings, :membership_autopay_window_days, if_exists: true
  end
end
