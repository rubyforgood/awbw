module EventAttendanceHelper
  # A minutes count as "6h 51m" (or "51m" under an hour, "0m" for zero) — how the
  # CE sign-in report totals attended time, replacing the paper sheet's minute math.
  def attendance_duration_label(minutes)
    minutes = minutes.to_i
    hours, mins = minutes.divmod(60)
    return "#{mins}m" if hours.zero?

    "#{hours}h #{mins}m"
  end
end
