# Callout drip dates are instants: an admin sets one in their own time zone, and
# every viewer sees it translated into theirs (each request runs in the user's zone).
class DripDate
  # The clock time is added only when it isn't the viewer's midnight, so cross-zone dates explain themselves.
  def self.label(time)
    return unless time

    local = time.in_time_zone
    date = local.to_date.to_fs(:long)
    return date if local.seconds_since_midnight.zero?

    "#{date} at #{local.strftime(local.min.zero? ? "%-l %p %Z" : "%-l:%M %p %Z")}"
  end

  # The editor's date-only field re-submits the stored date as shown in the editor's zone;
  # an unchanged date keeps the stored instant, so re-saving never moves a drip set elsewhere.
  # A changed date parses now, while the editor's zone is current (Rails would parse it lazily).
  def self.cast(current, value)
    return value unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    current&.in_time_zone&.to_date&.iso8601 == value ? current : Time.zone.parse(value)
  end
end
