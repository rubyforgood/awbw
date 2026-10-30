class AddIntendsToPayToContinuingEducationRegistrations < ActiveRecord::Migration[8.1]
  def up
    add_column :continuing_education_registrations, :intends_to_pay, :boolean, default: false, null: false
  end

  def down
    remove_column :continuing_education_registrations, :intends_to_pay, if_exists: true
  end
end
