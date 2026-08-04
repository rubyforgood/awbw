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

  validates :signed_in_at, presence: true
  validate :signed_out_after_signed_in

  scope :open, -> { where(signed_out_at: nil) }
  scope :closed, -> { where.not(signed_out_at: nil) }
  scope :chronological, -> { order(:signed_in_at) }

  # Still signed in — no sign-out recorded yet.
  def open?
    signed_out_at.nil?
  end

  # Whole minutes between sign-in and sign-out; nil while still open. Rounded to
  # the minute like the paper sheet, which staff totalled by the minute.
  def duration_minutes
    return nil unless signed_out_at && signed_in_at
    ((signed_out_at - signed_in_at) / 60).round
  end

  # The event day (a Date, in the app zone) this entry's sign-in falls on — how
  # the report groups entries into days.
  def attendance_date
    signed_in_at&.in_time_zone(Time.zone)&.to_date
  end

  private

  def signed_out_after_signed_in
    return if signed_out_at.blank? || signed_in_at.blank?
    return if signed_out_at > signed_in_at

    errors.add(:signed_out_at, "must be after the sign-in time")
  end
end
