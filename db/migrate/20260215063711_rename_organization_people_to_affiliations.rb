class RenameOrganizationPeopleToAffiliations < ActiveRecord::Migration[8.1]
  def change
    rename_table :organization_people, :affiliations
  end
end
