class RemoveCeHoursDetailsFromEvents < ActiveRecord::Migration[8.0]
  # CE page text moved onto the ce_hours registration_ticket_callout row (its
  # "Callout page text"), like every other built-in. These event columns are no
  # longer read or written. No backfill: the ticket system isn't in production use
  # for CE, and rows seed their own defaults.
  def up
    remove_column :events, :ce_hours_details, if_exists: true
    remove_column :events, :ce_hours_details_label, if_exists: true
  end

  def down
    add_column :events, :ce_hours_details, :text unless column_exists?(:events, :ce_hours_details)
    add_column :events, :ce_hours_details_label, :string, default: "CE hours", null: false unless column_exists?(:events, :ce_hours_details_label)
  end
end
