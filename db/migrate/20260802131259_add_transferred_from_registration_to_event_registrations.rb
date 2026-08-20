class AddTransferredFromRegistrationToEventRegistrations < ActiveRecord::Migration[8.1]
  # Records where a registration was transferred *from*: the incoming ("in")
  # registration points back at the outgoing ("out") one. Putting the FK on the
  # in-record means an in is identifiable directly (its FK is set) without
  # scanning every other row, while an out stays identifiable by its terminal
  # "transferred_out" status. See issue #1944.
  def up
    unless column_exists?(:event_registrations, :transferred_from_registration_id)
      add_column :event_registrations, :transferred_from_registration_id, :bigint
    end
    unless index_exists?(:event_registrations, :transferred_from_registration_id)
      add_index :event_registrations, :transferred_from_registration_id
    end
    unless foreign_key_exists?(:event_registrations, column: :transferred_from_registration_id)
      add_foreign_key :event_registrations, :event_registrations,
        column: :transferred_from_registration_id, on_delete: :nullify
    end

    # "transferred_in" is no longer an attendance status — the transfer link now
    # records the "in" relationship, freeing the status to track real attendance.
    # Existing transferred_in rows have no link to recover, so reset them to
    # registered (their default) rather than leaving an invalid status.
    execute("UPDATE event_registrations SET status = 'registered' WHERE status = 'transferred_in'")
  end

  def down
    # Best-effort inverse: rows still carrying a transfer link were the "in"s.
    execute("UPDATE event_registrations SET status = 'transferred_in' WHERE transferred_from_registration_id IS NOT NULL")
    remove_foreign_key :event_registrations, column: :transferred_from_registration_id, if_exists: true
    remove_index :event_registrations, :transferred_from_registration_id, if_exists: true
    remove_column :event_registrations, :transferred_from_registration_id, if_exists: true
  end
end
