# One registrant's attendance sheet for an event, as their own CE callout renders it:
# the training's days, their sessions on each, and the state the sign-in/out controls
# read. The registrant-facing counterpart to EventAttendanceReport.
#
# Times belong to the registrant, not to a licence — someone claiming CE against two
# licences sat in one room for one set of hours — so a sheet is built once per
# registration and rendered once per CE registration, each headed by its own licence.
#
# Entries come back decorated and are read a handful of times per page, so the whole
# sheet is one query grouped in Ruby.
class RegistrantAttendanceSheet
  def initialize(event_registration, at: Time.current)
    @registration = event_registration
    @at = at
  end

  # The training's calendar days — every one editable, whether or not it has times.
  def days
    @days ||= event.event_dates
  end

  def any_days?
    days.any?
  end

  # A day's sessions, decorated and in sign-in order.
  def entries_on(date)
    entries_by_day.fetch(date, [])
  end

  def day_minutes(date)
    entries_on(date).sum { |entry| entry.duration_minutes.to_i }
  end

  # Only the training's own days, so the total always equals the rows above it.
  def total_minutes
    days.sum { |date| day_minutes(date) }
  end

  def todays_entries
    entries_on(today)
  end

  # The entry they're currently signed in on, if any. Day-scoped like the model's:
  # a sign-out forgotten yesterday is #forgotten_entry's job, not today's Sign out.
  def open_entry
    @open_entry ||= todays_entries.select(&:open?).last
  end

  def signed_in?
    open_entry.present?
  end

  # An earlier day still hanging open, offered as its own catch-up close.
  def forgotten_entry
    @forgotten_entry ||= @registration.forgotten_sign_out_entry(today)&.decorate
  end

  # The time that catch-up close would record — that day's scheduled end.
  def forgotten_at
    @forgotten_at ||= forgotten_entry && @registration.forgotten_sign_out_at(forgotten_entry)
  end

  def window_open?
    event.attendance_sign_in_open?(@at)
  end

  def next_opens_at
    @next_opens_at ||= event.next_attendance_sign_in_opens_at(@at)
  end

  private

  def event
    @registration.event
  end

  def today
    @today ||= @at.in_time_zone(Time.zone).to_date
  end

  def entries_by_day
    @entries_by_day ||= @registration.event_attendance_time_entries.chronological
      .group_by(&:attendance_date)
      .transform_values { |entries| entries.map(&:decorate) }
  end
end
