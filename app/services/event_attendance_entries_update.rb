# Applies a batch of submitted sign-in/out rows to one registration's attendance
# entries — add, correct, remove — through the registration's nested-attributes
# setter, then attributes the change to the editing admin. Shared by the CE edit
# form (datetime rows spanning every day) and the attendance report's per-day inline
# editor (clock times against one known day): different row shapes on the way in, the
# same write on the way out.
#
# Rows are hashes (or permitted params) of "id", "signed_in_at", "signed_out_at" and
# "_destroy"; a row with no sign-in is an untouched blank and is dropped by the
# association's reject_if.
class EventAttendanceEntriesUpdate
  def initialize(registration, rows, editor:)
    @registration = registration
    @rows = rows
    @editor = editor
  end

  # Saves the batch, raising ActiveRecord::RecordInvalid so callers can roll back and
  # report. A no-op when there's nothing left to apply.
  def save!
    applicable = applicable_rows
    return if applicable.blank?

    registration.assign_attributes(event_attendance_time_entries_attributes: applicable)
    attribute_to_editor
    registration.save!
  end

  private

  attr_reader :registration, :rows, :editor

  # Drop rows pointing at an entry that's no longer on this registration — a stale
  # form or double-submit (it was already removed). Left in, nested attributes raise
  # RecordNotFound and blow up the save.
  def applicable_rows
    return [] if rows.blank?

    existing_ids = registration.event_attendance_time_entries.pluck(:id).map(&:to_s)
    rows.reject { |row| row["id"].present? && existing_ids.exclude?(row["id"].to_s) }
  end

  # Staff edits are the only attributed entries — registrant self-service sign-ins on
  # the public callout leave created_by nil.
  def attribute_to_editor
    registration.event_attendance_time_entries.each do |entry|
      next if entry.marked_for_destruction?

      entry.created_by ||= editor if entry.new_record?
      entry.updated_by = editor if entry.new_record? || entry.changed?
    end
  end
end
