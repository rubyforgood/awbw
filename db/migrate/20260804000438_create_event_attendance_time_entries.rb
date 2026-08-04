class CreateEventAttendanceTimeEntries < ActiveRecord::Migration[7.2]
  def up
    create_table :event_attendance_time_entries do |t|
      # No index on the reference itself: the FK rides the composite index below
      # (leftmost prefix), which must be declared in-table so MySQL doesn't
      # auto-create a redundant one for the FK.
      t.references :event_registration, null: false, foreign_key: true, index: false
      t.datetime :signed_in_at, null: false
      t.datetime :signed_out_at
      t.integer :created_by_id
      t.integer :updated_by_id

      t.timestamps

      # Fetching a registration's open (not-yet-signed-out) entry is the hot path.
      t.index [ :event_registration_id, :signed_out_at ],
        name: "index_attendance_entries_on_registration_and_signed_out"
    end

    add_index :event_attendance_time_entries, :created_by_id
    add_index :event_attendance_time_entries, :updated_by_id
  end

  def down
    drop_table :event_attendance_time_entries, if_exists: true
  end
end
