class AddApprovedAtToContinuingEducationRegistrations < ActiveRecord::Migration[8.1]
  def up
    add_column :continuing_education_registrations, :approved_at, :datetime unless column_exists?(:continuing_education_registrations, :approved_at)
  end

  def down
    remove_column :continuing_education_registrations, :approved_at, if_exists: true
  end
end
