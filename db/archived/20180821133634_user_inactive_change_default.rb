class UserInactiveChangeDefault < ActiveRecord::Migration[4.2]
  def change
    change_column_default(:users, :inactive, false)
  end
end
