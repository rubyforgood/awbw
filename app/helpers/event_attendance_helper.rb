module EventAttendanceHelper
  # The view-side front door to AttendanceTimeFormatter, which decorators and other
  # callers without a dependable view context use directly.
  def attendance_duration_label(minutes)
    AttendanceTimeFormatter.duration_label(minutes)
  end

  def attendance_clock_time(time)
    AttendanceTimeFormatter.clock_time(time)
  end

  # Identifies one reported line's sessions on one training day — the report's editable
  # unit. Doubles as the cell's DOM id, the `edit` param that opens it, and the anchor
  # the page returns to after a save. Keyed by the line (EventAttendanceReport::Row#key)
  # rather than the registration, so a registrant reported once per CE licence doesn't
  # get two cells sharing one id and opening both editors at once.
  def attendance_cell_id(row_key, date)
    "attendance-#{row_key}-#{date.iso8601}"
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
