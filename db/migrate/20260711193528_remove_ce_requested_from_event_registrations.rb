class RemoveCeRequestedFromEventRegistrations < ActiveRecord::Migration[8.1]
  # `ce_requested` was the intent flag mirrored by the existence of a
  # ContinuingEducationRegistration record. Every flow that set it also created
  # (or destroyed) the record in the same transaction, so `ce_registered?` is
  # the same signal — the column is redundant and is dropped here.
  def up
    remove_column :event_registrations, :ce_requested, if_exists: true
  end

  def down
    unless column_exists?(:event_registrations, :ce_requested)
      add_column :event_registrations, :ce_requested, :boolean, null: false, default: false
    end
  end
end
