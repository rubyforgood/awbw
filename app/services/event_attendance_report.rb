# Attendance sign-in/out for one event, grouped by day then registrant — the
# in-portal record that replaces AWBW's paper CE hour sign-in sheet (per-day tabs,
# each in/out pair, minutes totalled by staff). Generic: `ce_only:` scopes to CE
# registrants and surfaces their license number and awarded hours (what the CE
# board audits); the plain report covers anyone who logged time on any event day.
#
# All grouping/totals run over preloaded associations in Ruby (a training is a few
# dozen people with a handful of entries each), so building the whole report is a
# fixed handful of queries. Times use Time.zone — during a request that's the
# viewing admin's zone (Pacific), matching the callout and the paper sheet.
class EventAttendanceReport
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

  # Reported registrations, sorted by registrant name. The CE report lists every CE
  # registrant even before they've logged anything (so staff can chase sign-ins
  # during the training); the generic report lists only people who logged time.
  def registrations
    @registrations ||= scoped_registrations.sort_by { |reg| reg.registrant.full_name.to_s.downcase }
  end

  def any?
    registrations.any?
  end

  # Whether the event actually runs past the last reported date — event_dates is
  # capped at 5 days (Event#day_count's clamp), so a longer event has no sign-in
  # window or day section past day 5. The view warns when this is true.
  def dates_truncated?
    last_day = event.end_date&.in_time_zone(Time.zone)&.to_date
    return false unless last_day && dates.any?

    last_day > dates.last
  end

  # One registration's entries on one date, decorated and in sign-in order.
  def entries_for(registration, date)
    entries_on(registration, date).sort_by(&:signed_in_at).map(&:decorate)
  end

  def day_minutes(registration, date)
    entries_on(registration, date).sum { |entry| entry.duration_minutes.to_i }
  end

  # Sum of the per-day (event-day) minutes, so a registrant's Total logged always
  # equals its day columns. Time logged on dates outside the training's days isn't
  # part of the training, so it's excluded here (the certificate gate keeps its own
  # broader tally on EventRegistration).
  def total_minutes(registration)
    dates.sum { |date| day_minutes(registration, date) }
  end

  def grand_total_minutes
    registrations.sum { |reg| total_minutes(reg) }
  end

  # Everyone's logged minutes on one day — the day column's total in the All row.
  def day_grand_minutes(date)
    registrations.sum { |reg| day_minutes(reg, date) }
  end

  # Total CE hours awarded across all reported registrants — the All row's awarded figure.
  def total_hours_awarded
    registrations.sum { |reg| ce_hours(reg) }
  end

  # A registration with an entry still open (signed in, no sign-out) — flagged on
  # the report so a forgotten sign-out is fixable rather than silently under-counted.
  def open?(registration)
    registration.event_attendance_time_entries.any?(&:open?)
  end

  # CE-only columns.
  def license_numbers(registration)
    registration.continuing_education_registrations.filter_map { |ce| ce.professional_license&.number }.uniq
  end

  def ce_hours(registration)
    registration.continuing_education_registrations.sum { |ce| ce.hours.to_d }
  end

  # The registration's CE record, for the report's per-row "Edit" link to the CE
  # edit page. Nil for a non-CE registrant on the generic report.
  def ce_registration_for(registration)
    registration.continuing_education_registrations.first
  end

  private

  def entries_on(registration, date)
    registration.event_attendance_time_entries.select { |entry| entry.attendance_date == date }
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
