class ChangeMembershipDatesToDate < ActiveRecord::Migration[8.1]
  def up
    change_column :memberships, :start_date, :date
    change_column :memberships, :end_date, :date
  end

  def down
    change_column :memberships, :start_date, :datetime
    change_column :memberships, :end_date, :datetime
  end
end
