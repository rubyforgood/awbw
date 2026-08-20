class RemoveCeHoursDetailsFromEvents < ActiveRecord::Migration[8.0]
  # The CE hours heading and requirements copy now live on the materialized
  # ce_hours registration ticket callout row (title + description), not on the
  # event. No backfill: the built-ins re-seed and dev data re-seeds.
  def up
    remove_column :events, :ce_hours_details, if_exists: true
    remove_column :events, :ce_hours_details_label, if_exists: true
  end

  def down
    add_column :events, :ce_hours_details, :text unless column_exists?(:events, :ce_hours_details)
    unless column_exists?(:events, :ce_hours_details_label)
      add_column :events, :ce_hours_details_label, :string, default: "CE hours", null: false
    end
  end
end
