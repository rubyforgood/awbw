# One sign-in/sign-out pair for a registrant on a day of an event. Generic
# attendance timekeeping — many entries per day (people sign out for breaks and
# lunch and back in) — surfaced today only on the CE callout, but not CE-specific
# so any event day can use it. `signed_out_at` is nil while the person is still
# signed in (an "open" entry). Times are stored UTC and displayed in the app zone
# (Pacific), matching the paper CE sign-in sheet this replaces.
class EventAttendanceTimeEntry < ApplicationRecord
  belongs_to :event_registration
  # Registrant self-service sign-ins happen on the public (login-free) callout, so
  # created_by is nil for those; it's stamped only when staff add/edit an entry on
  # the CE edit form.
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # A single day can't hold more than a real day's worth of logged time.
  MAX_DAILY_MINUTES = 24 * 60

  validates :signed_in_at, presence: true
  validate :signed_out_after_signed_in
  validate :within_daily_limit
  validate :does_not_overlap_same_day

  scope :open, -> { where(signed_out_at: nil) }
  scope :closed, -> { where.not(signed_out_at: nil) }
  scope :chronological, -> { order(:signed_in_at) }

  # Still signed in — no sign-out recorded yet.
  def open?
    signed_out_at.nil?
  end

  # Whole minutes between sign-in and sign-out; nil while still open. Rounded to
  # the minute like the paper sheet, which staff totalled by the minute — except
  # a sub-minute pair counts as 1 (rounded up in the attendee's favor), never 0.
  def duration_minutes
    return nil unless signed_out_at && signed_in_at
    [ ((signed_out_at - signed_in_at) / 60).round, 1 ].max
  end

  # The event day (a Date, in the app zone) this entry's sign-in falls on — how
  # the report groups entries into days.
  def attendance_date
    signed_in_at&.in_time_zone(Time.zone)&.to_date
  end

  private

  # On :base and phrased as a whole sentence like the other two guards: these reach
  # the admin through the parent registration's nested attributes, which pastes the
  # humanized association name in front of anything keyed to an attribute.
  def signed_out_after_signed_in
    return if signed_out_at.blank? || signed_in_at.blank?
    return if signed_out_at > signed_in_at

    errors.add(:base, "Sign-out must be after the sign-in time.")
  end

  # The day's total logged time (this entry plus its same-day siblings) can't exceed
  # 24 hours — catches fat-fingered edits like a 19-hour session.
  def within_daily_limit
    return unless own_range_valid?

    total = duration_minutes.to_i + same_day_siblings.sum { |entry| entry.duration_minutes.to_i }
    return if total <= MAX_DAILY_MINUTES

    errors.add(:base, "Total time on #{day_label} can't exceed 24 hours.")
  end

  # An entry can't fall within (or straddle) another sign-in's timeframe on the same
  # day — you can't be signed in twice at once.
  def does_not_overlap_same_day
    return unless own_range_valid?

    my_end = signed_out_at || signed_in_at
    clash = same_day_siblings.find do |entry|
      entry_end = entry.signed_out_at || entry.signed_in_at
      signed_in_at < entry_end && entry.signed_in_at < my_end
    end
    return unless clash

    errors.add(:base, "This sign-in overlaps another entry on #{day_label}.")
  end

  # Only run the cross-entry guards on a well-formed range (presence + order are
  # checked separately), so we never compare against a backwards interval.
  def own_range_valid?
    return false if signed_in_at.blank?

    signed_out_at.blank? || signed_out_at > signed_in_at
  end

  # This registration's other entries on the same day. Starts from the persisted
  # rows (queried fresh, not the possibly-stale association cache) and overlays the
  # in-memory collection when it's loaded — so the CE edit form, which assigns every
  # row through nested attributes, compares against siblings-in-progress (and their
  # unsaved edits) too. Excludes self and rows being removed.
  def same_day_siblings
    registration = event_registration
    return [] unless registration && attendance_date

    by_key = {}
    if registration.persisted?
      EventAttendanceTimeEntry.where(event_registration_id: registration.id).find_each do |entry|
        by_key[entry.id] = entry
      end
    end
    if registration.event_attendance_time_entries.loaded?
      registration.event_attendance_time_entries.target.each do |entry|
        by_key[entry.id || entry.object_id] = entry
      end
    end

    by_key.values.reject do |entry|
      entry.equal?(self) ||
        (persisted? && entry.id == id) ||
        entry.marked_for_destruction? ||
        entry.signed_in_at.blank? ||
        entry.attendance_date != attendance_date
    end
  end

  def day_label
    attendance_date.strftime("%b %-d")
  end
end
