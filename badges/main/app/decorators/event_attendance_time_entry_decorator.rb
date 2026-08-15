class EventAttendanceTimeEntryDecorator < ApplicationDecorator
  delegate_all

  # Formatting comes straight from AttendanceTimeFormatter rather than through `h`:
  # the report decorates entries from a service, where the current view context can be
  # a leftover mailer one that doesn't carry EventAttendanceHelper.

  # Clock time of the sign-in, in the app zone — e.g. "8:50 AM".
  def signed_in_label
    AttendanceTimeFormatter.clock_time(signed_in_at)
  end

  # Clock time of the sign-out, or an em dash while still signed in.
  def signed_out_label
    signed_out_at ? AttendanceTimeFormatter.clock_time(signed_out_at) : "—"
  end

  # Elapsed time as "1h 44m" (or "44m" under an hour); "In progress" while open.
  def duration_label
    minutes = duration_minutes
    return "In progress" unless minutes

    AttendanceTimeFormatter.duration_label(minutes)
  end
end
