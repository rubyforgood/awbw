class UserConfirmedChangeDefault < ActiveRecord::Migration[4.2]
  def change
    change_column_default(:users, :confirmed, true)
  end
end
