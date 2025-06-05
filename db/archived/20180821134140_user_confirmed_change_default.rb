class UserConfirmedChangeDefault < ActiveRecord::Migration
  def change
    change_column_default(:users, :confirmed, true)
  end
end
