class RemoveCeColumnsFromEventRegistrations < ActiveRecord::Migration[8.1]
  # CE is now tracked as ContinuingEducationRegistration records, so these flat
  # columns are obsolete. No data to preserve (the CE form was never used in
  # production).
  def up
    remove_column :event_registrations, :ce_credit_requested, if_exists: true
    remove_column :event_registrations, :ce_hours_requested, if_exists: true
    remove_column :event_registrations, :ce_license_number, if_exists: true
  end

  def down
    add_column :event_registrations, :ce_credit_requested, :boolean, null: false, default: false unless column_exists?(:event_registrations, :ce_credit_requested)
    add_column :event_registrations, :ce_hours_requested, :integer unless column_exists?(:event_registrations, :ce_hours_requested)
    add_column :event_registrations, :ce_license_number, :string unless column_exists?(:event_registrations, :ce_license_number)
  end
end
