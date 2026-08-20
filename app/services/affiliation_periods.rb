# An affiliation history as merged periods: overlapping intervals collapse, a real
# gap starts a new period, and the periods join chronologically with ", ".
#
#   * :year (default) — "Affiliated since", e.g. "2010-2012, 2026". A lone ongoing
#     period keeps its month when it began this year ("Jul 2026").
#   * :month — "Art program since", e.g. "Aug 2015 – Jun 2018, Feb 2024", where the
#     month a program started or lapsed is the point.
#
# Nil when no affiliation carries a start date, so callers can fall back to the
# organization's own start_date.
class AffiliationPeriods
  PRECISIONS = %i[ year month ].freeze

  def self.label(affiliations, today: Date.current, precision: :year)
    new(affiliations, today: today, precision: precision).label
  end

  def initialize(affiliations, today: Date.current, precision: :year)
    raise ArgumentError, "unknown precision #{precision.inspect}" unless PRECISIONS.include?(precision)

    @today = today
    @precision = precision
    @intervals = affiliations
      .filter_map { |affiliation| interval_for(affiliation) }
      .sort_by { |start, _finish| start }
  end

  def label
    return nil if @intervals.empty?

    periods = merged
    # A single ongoing period is a fresh org — worth the month's precision.
    if @precision == :year && periods.one? && ongoing?(periods.first[1])
      return year_or_month(periods.first[0])
    end

    periods.map { |period| format_period(period) }.join(", ")
  end

  private

  # Affiliations without a start date can't be placed on the timeline.
  def interval_for(affiliation)
    return nil if affiliation.start_date.blank?

    [ affiliation.start_date.to_date, affiliation.end_date&.to_date ]
  end

  def merged
    @intervals.each_with_object([]) do |(start, finish), periods|
      last = periods.last
      if last && overlaps?(last, start)
        last[1] = later_end(last[1], finish)
      else
        periods << [ start, finish ]
      end
    end
  end

  # A nil end is ongoing and swallows every later interval.
  def overlaps?(period, next_start)
    period[1].nil? || next_start <= period[1]
  end

  def later_end(current, other)
    return nil if current.nil? || other.nil?

    [ current, other ].max
  end

  def ongoing?(finish)
    finish.nil? || finish >= @today
  end

  def format_period((start, finish))
    return month_period(start, finish) if @precision == :month
    return start.year.to_s if ongoing?(finish) || start.year == finish.year

    "#{start.year}-#{finish.year}"
  end

  def month_period(start, finish)
    return month(start) if ongoing?(finish)

    "#{month(start)} – #{month(finish)}"
  end

  def month(date)
    date.strftime("%b %Y")
  end

  def year_or_month(date)
    date.year == @today.year ? month(date) : date.year.to_s
  end
end
