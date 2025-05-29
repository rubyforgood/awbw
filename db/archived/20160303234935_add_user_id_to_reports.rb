class AddUserIdToReports < ActiveRecord::Migration[4.2]
  def change
    add_reference :reports, :user, index: true
    add_foreign_key :reports, :users
  end
end
