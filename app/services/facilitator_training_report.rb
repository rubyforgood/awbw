# Cross-event summary of a year's facilitator trainings: scholarship dollars and
# award counts (funded vs unfunded) plus trainee counts, one column per training.
# Funded vs unfunded follows the same convention as everywhere else — a
# scholarship is funded when a grant backs it — sourced from EventDashboard so
# the definition lives in one place.
#
# Trainee counts split by delivery format: scheduled multi-day sessions total
# under "2-Day" and self-paced ones (event.on_demand?) under "On-Demand".
#
# Give it a collection of facilitator-training events; it groups them by calendar
# year, newest first, each year a table's worth of columns with its own totals.
class FacilitatorTrainingReport
  # One facilitator-training event's column. Delegates the funded/unfunded splits
  # to EventDashboard so the money and count conventions can't drift.
  Column = Struct.new(:event, :dashboard, keyword_init: true) do
    def funded_cents = dashboard.funded_scholarship_cents
    def unfunded_cents = dashboard.unfunded_scholarship_cents
    def scholarship_cents = funded_cents + unfunded_cents

    def funded_count = dashboard.funded_scholarship_count
    def unfunded_count = dashboard.unfunded_scholarship_count
    def scholarship_count = funded_count + unfunded_count

    def trainee_count = dashboard.registrant_count

    def on_demand? = event.on_demand?

    def label = event.decorate.compact_label
    def date_label = event.start_date? ? event.decorate.short_date_range : nil
  end

  # The figures summed across a year's columns for the totals row.
  SUMMABLE = %i[
    funded_cents unfunded_cents scholarship_cents
    funded_count unfunded_count scholarship_count trainee_count
  ].freeze

  # One calendar year of facilitator trainings, with its columns and totals.
  YearGroup = Struct.new(:year, :columns, keyword_init: true) do
    SUMMABLE.each do |attribute|
      define_method(attribute) { columns.sum(&attribute) }
    end

    # Trainee totals split by delivery format — these sum to trainee_count.
    def two_day_trainee_count = columns.reject(&:on_demand?).sum(&:trainee_count)
    def on_demand_trainee_count = columns.select(&:on_demand?).sum(&:trainee_count)
  end

  def initialize(events)
    @events = events
  end

  def any?
    years.any?
  end

  # Calendar-year groups, newest first. Events without a start date fall under a
  # nil year that sorts last.
  def years
    @years ||= @events
      .group_by { |event| event.start_date&.year }
      .map { |year, year_events| YearGroup.new(year: year, columns: columns_for(year_events)) }
      .sort_by { |group| [ group.year ? 0 : 1, -(group.year || 0) ] }
  end

  private

  def columns_for(events)
    events
      .sort_by { |event| event.start_date || Time.zone.at(0) }
      .map { |event| Column.new(event: event, dashboard: EventDashboard.new(event)) }
  end
end
