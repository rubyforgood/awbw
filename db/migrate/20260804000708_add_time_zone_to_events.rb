class AddTimeZoneToEvents < ActiveRecord::Migration[8.1]
  # Nullable with no default: existing rows stay NULL (no backfill), and the app
  # treats a blank zone as Pacific via Event#event_zone. New events entered through
  # the form carry an explicit zone (the selector defaults to Pacific).
  def up
    add_column :events, :time_zone, :string
  end

  def down
    remove_column :events, :time_zone, if_exists: true
  end
end
