class AddUserIdToReports < ActiveRecord::Migration
  def change
    add_reference :reports, :user, index: true
    add_foreign_key :reports, :users
  end
end
