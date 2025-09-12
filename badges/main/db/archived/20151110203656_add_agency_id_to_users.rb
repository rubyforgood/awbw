class AddAgencyIdToUsers < ActiveRecord::Migration
  def change
    add_reference :users, :agency, index: true
    add_foreign_key :users, :agencies
  end
end
