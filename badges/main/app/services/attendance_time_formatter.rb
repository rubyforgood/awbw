# Renders attendance times and totals the one way they should read everywhere — the
# CE sign-in report, the registrant's callout, the entry decorator, and the
# sign-in/out flash notices.
#
# A PORO rather than the helper alone because decorators reach these from wherever
# they happen to be called. Draper resolves `h` against whichever view context is
# current, and outside a request that can be a mailer's (ApplicationMailer pulls in
# ApplicationHelper only), which doesn't carry EventAttendanceHelper. Same split as
# MoneyFormatter: EventAttendanceHelper is the view-side front door, this is what
# callers without a dependable view context use.
class AttendanceTimeFormatter
  # A datetime as its clock time in the app zone — "9:02 AM".
  def self.clock_time(time)
    time.in_time_zone(Time.zone).strftime("%-l:%M %p")
  end

  # A minutes count as "6h 51m" (or "51m" under an hour, "0m" for zero) — how the CE
  # sign-in report totals attended time, replacing the paper sheet's minute math.
  def self.duration_label(minutes)
    hours, mins = minutes.to_i.divmod(60)
    return "#{mins}m" if hours.zero?

    "#{hours}h #{mins}m"
  end
end
