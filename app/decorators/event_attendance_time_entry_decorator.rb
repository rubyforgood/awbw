class EventAttendanceTimeEntryDecorator < ApplicationDecorator
  delegate_all

  # Clock time of the sign-in, in the app zone — e.g. "8:50 AM".
  def signed_in_label
    format_time(signed_in_at)
  end

  # Clock time of the sign-out, or an em dash while still signed in.
  def signed_out_label
    signed_out_at ? format_time(signed_out_at) : "—"
  end

  # Elapsed time as "1h 44m" (or "44m" under an hour); "In progress" while open.
  def duration_label
    minutes = duration_minutes
    return "In progress" unless minutes

    h.attendance_duration_label(minutes)
  end

  private

  def format_time(time)
    time.in_time_zone(Time.zone).strftime("%-l:%M %p")
  end
end
