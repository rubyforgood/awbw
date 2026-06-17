class AddCeHoursAndLicenseToEventRegistrations < ActiveRecord::Migration[8.1]
  def up
    add_column :event_registrations, :ce_hours_requested, :integer unless column_exists?(:event_registrations, :ce_hours_requested)
    add_column :event_registrations, :ce_license_number, :string unless column_exists?(:event_registrations, :ce_license_number)
  end

  def down
    remove_column :event_registrations, :ce_hours_requested, if_exists: true
    remove_column :event_registrations, :ce_license_number, if_exists: true
  end
end
