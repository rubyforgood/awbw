class DisallowNullSuperUserOnUsers < ActiveRecord::Migration[8.1]
  def up
    change_column_null :users, :super_user, false, false
  end

  def down
    change_column_null :users, :super_user, true
  end
end
