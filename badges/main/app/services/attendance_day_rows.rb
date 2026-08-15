# One training day's submitted sign-in/out rows from an inline attendance editor.
#
# The editors send clock times ("08:50") rather than datetimes — the day comes from
# the section the editor was opened in, so a correction is two fields instead of two
# dates to retype. Both the admin report's per-day editor
# (EventRegistrationsController#update_attendance) and the registrant's own editor on
# the CE callout (Events::CalloutsController#update_ce_attendance) post the same
# `attendance[entries][i][in|out|id|_destroy]` shape, so both read it through here.
class AttendanceDayRows
  # The training day an editor was opened on. Nil for anything unparseable — the date
  # comes from the page's own day sections, so a bad one is a broken request.
  def self.date_from(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def initialize(params, date)
    @params = params
    @date = date
  end

  # The rows exactly as submitted. Handed back through the flash when a save is
  # rejected, so the editor reopens with what was typed.
  def submitted
    @submitted ||= @params.fetch(:attendance, {})
      .permit(entries: [ :id, :in, :out, :_destroy ])
      .fetch(:entries, {})
      .values
      .map { |row| row.to_h.stringify_keys }
  end

  # The same rows as attendance-entry attributes, each clock time bound to the day.
  def entry_attributes
    submitted.map do |row|
      { "id" => row["id"],
        "signed_in_at" => time_at(row["in"]),
        "signed_out_at" => time_at(row["out"]),
        "_destroy" => row["_destroy"] }
    end
  end

  private

  # Blank stays blank: an empty sign-in marks an untouched row (dropped by the
  # association's reject_if), an empty sign-out leaves the session open.
  def time_at(clock)
    return nil if clock.blank?

    Time.zone.parse("#{@date.iso8601} #{clock}")
  end
end
