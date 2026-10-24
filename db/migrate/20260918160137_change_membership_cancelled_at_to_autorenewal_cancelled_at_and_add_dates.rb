class ChangeMembershipCancelledAtToAutorenewalCancelledAtAndAddDates < ActiveRecord::Migration[8.1]
  def change
    rename_column :memberships, :cancelled_at, :autorenewal_cancelled_at
    add_column :memberships, :start_date, :datetime
    add_column :memberships, :end_date, :datetime
  end
end
