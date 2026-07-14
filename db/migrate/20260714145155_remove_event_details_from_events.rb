class RemoveEventDetailsFromEvents < ActiveRecord::Migration[8.0]
  # The "Before you attend" content moved onto the event_details
  # registration_ticket_callout row (its title + "Callout page text"), which now
  # renders on the generic callout page like every other content built-in. These
  # event columns are no longer read or written. No backfill.
  def up
    remove_column :events, :event_details, if_exists: true
    remove_column :events, :event_details_label, if_exists: true
  end

  def down
    add_column :events, :event_details, :text unless column_exists?(:events, :event_details)
    add_column :events, :event_details_label, :string, default: "Before you attend", null: false unless column_exists?(:events, :event_details_label)
  end
end
