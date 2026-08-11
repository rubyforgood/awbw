# Applies a batch of submitted sign-in/out rows to one registration's attendance
# entries — add, correct, remove — through the registration's nested-attributes
# setter, then attributes the change to the editing admin. Shared by the CE edit
# form (datetime rows spanning every day), the attendance report's per-day inline
# editor, and the registrant's own per-day editor on the CE callout (clock times
# against one known day): different row shapes on the way in, the same write out.
#
# Rows are hashes (or permitted params) of "id", "signed_in_at", "signed_out_at" and
# "_destroy"; a row with no sign-in is an untouched blank and is dropped by the
# association's reject_if.
#
# `editor:` is the admin making a staff correction, or nil when the registrant is
# editing their own times — those stay unattributed, like their sign-in/out taps.
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

    @registration.assign_attributes(event_attendance_time_entries_attributes: applicable)
    # Nested attributes only add the submitted rows to the association's target;
    # loading it merges in the rest, so each entry's cross-entry guards (overlap, the
    # daily limit) compare against its siblings-in-progress and their unsaved edits.
    @registration.event_attendance_time_entries.load
    attribute_to_editor if @editor
    @registration.save!
  end

  private

  # Drop rows pointing at an entry that's no longer on this registration — a stale
  # form or double-submit (it was already removed). Left in, nested attributes raise
  # RecordNotFound and blow up the save.
  def applicable_rows
    return [] if @rows.blank?

    existing_ids = @registration.event_attendance_time_entries.pluck(:id).map(&:to_s)
    @rows.reject { |row| row["id"].present? && existing_ids.exclude?(row["id"].to_s) }
  end

  # Staff edits are the only attributed entries — anything the registrant does on the
  # public callout (signing in, signing out, correcting a time) leaves created_by nil.
  def attribute_to_editor
    @registration.event_attendance_time_entries.each do |entry|
      next if entry.marked_for_destruction?

      entry.created_by ||= @editor if entry.new_record?
      entry.updated_by = @editor if entry.new_record? || entry.changed?
    end
  end
end
