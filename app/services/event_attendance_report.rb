# Attendance sign-in/out for one event, grouped by day then reported line — the
# in-portal record that replaces AWBW's paper CE hour sign-in sheet (per-day tabs,
# each in/out pair, minutes totalled by staff). Generic: `ce_only:` scopes to CE
# registrants and surfaces their license number and awarded hours (what the CE
# board audits); the plain report covers anyone who logged time on any event day.
#
# The reported unit is a Row, not a registration: on the CE report a registrant
# claiming CE against two licences gets a line each, since the two boards audit
# separately and each is shown only its own licence and hours. The times behind those
# lines are shared — one person, one room, one set of hours — which is why the
# everyone-totals dedupe by registration while hours awarded sum across lines.
#
# All grouping/totals run over preloaded associations in Ruby (a training is a few
# dozen people with a handful of entries each), so building the whole report is a
# fixed handful of queries. Times use Time.zone — during a request that's the
# viewing admin's zone (Pacific), matching the callout and the paper sheet.
class EventAttendanceReport
  # One reported line. `ce_registration` is nil on the generic report, where a
  # registrant is only ever one line.
  Row = Struct.new(:registration, :ce_registration) do
    # Identifies the line across the page — its cell ids, the `edit` param that opens
    # an editor on it, and the anchor a save returns to. A registration alone isn't
    # enough: two licences would share one id and open both editors at once.
    def key
      [ registration.id, ce_registration&.id ].compact.join("-")
    end

    def name
      registration.registrant.full_name.to_s
    end

    def license_number
      ce_registration&.professional_license&.number
    end

    def hours_awarded
      ce_registration&.hours.to_d
    end
  end

  def initialize(event, ce_only: false)
    @event = event
    @ce_only = ce_only
  end

  attr_reader :event

  def ce_only?
    @ce_only
  end

  # The event's calendar days — the report's top-level grouping (Day 1, Day 2, …).
  def dates
    event.event_dates
  end

  # Reported lines, sorted by registrant name then licence number. The CE report lists
  # every CE registration even before anything has been logged (so staff can chase
  # sign-ins during the training); the generic report lists only people who logged time.
  def rows
    @rows ||= scoped_registrations
      .sort_by { |registration| registration.registrant.full_name.to_s.downcase }
      .flat_map { |registration| rows_for(registration) }
  end

  # The distinct people behind those lines — what the everyone-totals count.
  def reported_registrations
    @reported_registrations ||= rows.map(&:registration).uniq
  end

  def any?
    rows.any?
  end

  # Whether the event actually runs past the last reported date. The view warns when
  # this is true; the registrant's own sheet warns off the same rule.
  def dates_truncated?
    event.event_dates_truncated?
  end

  # One line's entries on one date, decorated and in sign-in order.
  def entries_for(row, date)
    entries_on(row.registration, date).sort_by(&:signed_in_at).map(&:decorate)
  end

  def day_minutes(row, date)
    minutes_on(row.registration, date)
  end

  # Sum of the per-day (event-day) minutes, so a line's Total logged always equals its
  # day columns. Time logged on dates outside the training's days isn't part of the
  # training, so it's excluded here (the certificate gate keeps its own broader tally
  # on EventRegistration).
  def total_minutes(row)
    dates.sum { |date| minutes_on(row.registration, date) }
  end

  # Everyone's logged minutes, over the people rather than the lines: two licences
  # share one set of times, so summing the lines would bank that person's hours twice.
  def grand_total_minutes
    reported_registrations.sum { |registration| dates.sum { |date| minutes_on(registration, date) } }
  end

  # Everyone's logged minutes on one day — the day column's total in the All row.
  def day_grand_minutes(date)
    reported_registrations.sum { |registration| minutes_on(registration, date) }
  end

  # CE hours awarded across every reported line — the All row's awarded figure. Summed
  # per line, not per person: each board awards its own hours against its own licence.
  def total_hours_awarded
    rows.sum(&:hours_awarded)
  end

  # A line with an entry still open (signed in, no sign-out) — flagged on the report so
  # a forgotten sign-out is fixable rather than silently under-counted.
  def open?(row)
    row.registration.event_attendance_time_entries.any?(&:open?)
  end

  private

  def rows_for(registration)
    return [ Row.new(registration, nil) ] unless ce_only?

    registration.continuing_education_registrations
      .sort_by { |ce| ce.professional_license&.number.to_s }
      .map { |ce| Row.new(registration, ce) }
  end

  def entries_on(registration, date)
    registration.event_attendance_time_entries.select { |entry| entry.attendance_date == date }
  end

  def minutes_on(registration, date)
    entries_on(registration, date).sum { |entry| entry.duration_minutes.to_i }
  end

  def scoped_registrations
    list = event.event_registrations
      .includes(:registrant, :event_attendance_time_entries,
        continuing_education_registrations: :professional_license)
      .to_a
    if ce_only?
      list.select { |reg| reg.continuing_education_registrations.any? }
    else
      list.select { |reg| reg.event_attendance_time_entries.any? }
    end
  end
end
