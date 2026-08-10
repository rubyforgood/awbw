# Resolves the reports-hub period toggle ("this_year" | "last_year" |
# "all_time") to a metric scope + display label for a report's summary card.
# Included by EventRevenueReport and EventParticipationReport, which each supply
# an empty_year_group for a year that has no events (so the card shows zeros).
module ReportPeriods
  # A resolved period: the label to show, the calendar year (nil for all time),
  # and the object the summary card reads its figures from — a YearGroup for a
  # single year, or the report itself for all time.
  PeriodScope = Struct.new(:label, :year, :metrics, keyword_init: true)

  def period_scope(period, current_year: @current_year)
    case period
    when "all_time"
      PeriodScope.new(label: "All time", year: nil, metrics: self)
    when "last_year"
      year_period(current_year - 1)
    else
      year_period(current_year)
    end
  end

  private

  def year_period(year)
    metrics = years.find { |group| group.year == year } || empty_year_group(year)
    PeriodScope.new(label: year.to_s, year: year, metrics: metrics)
  end
end
