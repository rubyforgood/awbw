class AddNotNullToMembershipsDates < ActiveRecord::Migration[8.1]
  def up
    change_column_null :memberships, :start_date, false
    change_column_null :memberships, :end_date, false
  end

  def down
    change_column_null :memberships, :start_date, true
    change_column_null :memberships, :end_date, true
  end
end
