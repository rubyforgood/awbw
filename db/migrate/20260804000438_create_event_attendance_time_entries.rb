class CreateEventAttendanceTimeEntries < ActiveRecord::Migration[7.2]
  def up
    create_table :event_attendance_time_entries do |t|
      t.references :event_registration, null: false, foreign_key: true, index: true
      t.datetime :signed_in_at, null: false
      t.datetime :signed_out_at
      t.integer :created_by_id
      t.integer :updated_by_id

      t.timestamps
    end

    add_index :event_attendance_time_entries, :created_by_id
    add_index :event_attendance_time_entries, :updated_by_id
    # Fetching a registration's open (not-yet-signed-out) entry is the hot path.
    add_index :event_attendance_time_entries, [ :event_registration_id, :signed_out_at ],
      name: "index_attendance_entries_on_registration_and_signed_out"
  end

  def down
    drop_table :event_attendance_time_entries, if_exists: true
  end
end
