class AddUserIdToWorkshops < ActiveRecord::Migration
  def change
    add_reference :workshops, :user, index: true
    add_foreign_key :workshops, :users
  end
end
