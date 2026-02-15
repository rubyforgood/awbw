class AddStartDateAndEndDateToOrganizationPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :organization_people, :start_date, :date
    add_column :organization_people, :end_date, :date
  end
end
