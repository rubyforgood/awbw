class RemoveEventDetailsFromEvents < ActiveRecord::Migration[8.0]
  # The "Before you attend" / art-supplies copy now lives on the materialized
  # art_supplies registration ticket callout row, not on the event. No backfill:
  # the built-ins re-seed and dev data re-seeds.
  def up
    remove_column :events, :event_details, if_exists: true
    remove_column :events, :event_details_label, if_exists: true
  end

  def down
    add_column :events, :event_details, :text unless column_exists?(:events, :event_details)
    unless column_exists?(:events, :event_details_label)
      add_column :events, :event_details_label, :string, default: "Before you attend", null: false
    end
  end
end
