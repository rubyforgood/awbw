class AddUserIdToWorkshops < ActiveRecord::Migration[4.2]
  def change
    add_reference :workshops, :user, index: true
    add_foreign_key :workshops, :users
  end
end
