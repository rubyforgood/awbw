class AddNotNullToMembershipsDates < ActiveRecord::Migration[8.1]
  def change
    change_column_null :memberships, :start_date, false
    change_column_null :memberships, :end_date, false
  end
end
