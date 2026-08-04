module EventAttendanceHelper
  # A minutes count as "6h 51m" (or "51m" under an hour, "0m" for zero) — how the
  # CE sign-in report totals attended time, replacing the paper sheet's minute math.
  def attendance_duration_label(minutes)
    minutes = minutes.to_i
    hours, mins = minutes.divmod(60)
    return "#{mins}m" if hours.zero?

    "#{hours}h #{mins}m"
  end

  # A datetime as its clock time in the app zone — "9:02 AM". Shared by the entry
  # decorator, the sign-in/out flash notices, and the callout's catch-up prompt so
  # every attendance time on screen reads the same.
  def attendance_clock_time(time)
    time.in_time_zone(Time.zone).strftime("%-l:%M %p")
  end

  # Identifies one registrant's sessions on one training day — the report's editable
  # unit. Doubles as the cell's DOM id, the `edit` param that opens it, and the anchor
  # the page returns to after a save.
  def attendance_cell_id(registration, date)
    "attendance-#{registration.id}-#{date.iso8601}"
  end

  # The rows the inline day editor renders: one per logged session plus a trailing
  # blank to add another (fill it and save, same as the CE edit page's table). After a
  # rejected save the submitted values come back through the flash, so a validation
  # error doesn't cost the admin what they typed.
  def attendance_editor_rows(entries)
    rows = flash[:attendance_rows].presence || entries.map { |entry|
      { "id" => entry.id.to_s, "in" => attendance_input_time(entry.signed_in_at), "out" => attendance_input_time(entry.signed_out_at) }
    }
    rows.reject { |row| row.values_at("id", "in", "out").all?(&:blank?) } + [ {} ]
  end

  # A datetime as the "HH:MM" an <input type="time"> expects, in the app zone.
  def attendance_input_time(time)
    time&.in_time_zone(Time.zone)&.strftime("%H:%M")
  end
end
