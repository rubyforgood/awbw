# Formats an affiliation history as merged periods. Each affiliation is a
# [start_date, end_date] interval (a nil end = ongoing); overlapping or touching
# intervals collapse into one period, and a real gap starts a new one. Periods
# join chronologically with ", ".
#
# Two precisions, because the two displays want different granularity:
#   * :year (default) — "Affiliated since". A lone ongoing period (a fresh org)
#     shows "Mon YYYY" when it began this year (e.g. "Jul 2026"), otherwise just
#     its start year. In a multi-period list every period is year-only for
#     consistency: ongoing is its start year, closed is "YYYY" (same-year) or
#     "YYYY-YYYY" — e.g. "2010-2012, 2026".
#   * :month — "Art program since", where the exact month a program started or
#     lapsed matters. Ongoing is "Mon YYYY", closed is "Mon YYYY – Mon YYYY" —
#     e.g. "Aug 2015 – Jun 2018, Feb 2024".
#
# Returns nil when no affiliation carries a start date, so callers can fall back
# to the organization's own start_date.
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
    # At year precision a single ongoing period is a fresh org — worth the month's
    # precision. At month precision every period already carries its month.
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
