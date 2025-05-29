class AddAgencyIdToUsers < ActiveRecord::Migration[4.2]
  def change
    add_reference :users, :agency, index: true
    add_foreign_key :users, :agencies
  end
end
