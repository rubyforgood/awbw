class UserInactiveChangeDefault < ActiveRecord::Migration
  def change
    change_column_default(:users, :inactive, false)
  end
end
