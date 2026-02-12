class RenameOrganizationUsersToOrganizationPeople < ActiveRecord::Migration[8.1]
  def change
    rename_table :organization_users, :organization_people
    add_reference :organization_people, :person, null: true, index: true
  end
end
