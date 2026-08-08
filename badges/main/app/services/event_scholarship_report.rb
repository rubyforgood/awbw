# Scholarship report: scholarship dollars and award counts (funded vs unfunded)
# per facilitator training, grouped by calendar year. The sibling of
# EventRevenueReport / EventParticipationReport — same year-grouped shape and
# statistics-hub period card, but counting scholarships.
#
# Funded vs unfunded follows the app-wide convention (see EventDashboard):
# funded = backed by an external grant; unfunded = no grant, or a grant the org
# (AWBW) donated to itself. Alongside the money it carries a trainee headcount —
# people who ATTENDED — split by delivery format: scheduled sessions total under
# "Training" and self-paced ones (event.on_demand?) under "On-demand".
#
# Give it a collection of (decorated) facilitator-training events.
class EventScholarshipReport
  # One training's column. Sources every figure from EventDashboard so the
  # funded/unfunded and attendance conventions can't drift from the dashboard.
  Column = Struct.new(:event, :dashboard, keyword_init: true) do
    def funded_cents = dashboard.funded_scholarship_cents
    def unfunded_cents = dashboard.unfunded_scholarship_cents
    def scholarship_cents = funded_cents + unfunded_cents

    def funded_count = dashboard.funded_scholarship_count
    def unfunded_count = dashboard.unfunded_scholarship_count
    def scholarship_count = funded_count + unfunded_count

    # Trainees who fully attended (registration status "attended").
    def attended_count = dashboard.attendance_count_for("attended")

    def on_demand? = event.on_demand?
    def label = event.compact_label
    def date_label = event.start_date? ? event.short_date_range : nil
    def year = event.start_date&.year
  end

  # The additive figures — summed across a year's columns for its totals, and
  # across every column for the all-time total.
  SUMMABLE = %i[
    funded_cents unfunded_cents scholarship_cents
    funded_count unfunded_count scholarship_count attended_count
  ].freeze

  module Aggregates
    SUMMABLE.each do |attribute|
      define_method(attribute) { columns.sum(&attribute) }
    end

    # Attendance split by delivery format — these sum to attended_count.
    def training_attended_count = columns.reject(&:on_demand?).sum(&:attended_count)
    def on_demand_attended_count = columns.select(&:on_demand?).sum(&:attended_count)

    # Distinct scholarship recipients who attended (registration status
    # "attended") — people, not seats: someone who holds a scholarship across two
    # of these trainings counts once. Split by delivery format (a person attending
    # both formats counts in each split, so the two need not sum to the total).
    def recipients_attended_count = distinct_attended_recipient_count(columns.map { |column| column.event.id })
    def training_recipients_attended_count = distinct_attended_recipient_count(columns.reject(&:on_demand?).map { |column| column.event.id })
    def on_demand_recipients_attended_count = distinct_attended_recipient_count(columns.select(&:on_demand?).map { |column| column.event.id })

    private

    def distinct_attended_recipient_count(event_ids)
      return 0 if event_ids.empty?
      EventRegistration.attended.with_scholarship.where(event_id: event_ids).distinct.count(:registrant_id)
    end
  end

  # One calendar year of trainings, with its columns and totals.
  YearGroup = Struct.new(:year, :columns, :in_progress, keyword_init: true) do
    include Aggregates
  end

  include Aggregates
  include ReportPeriods

  def initialize(events, current_year: Date.current.year, featured_year: nil, funder: nil)
    @events = events.to_a
    @current_year = current_year
    # nil means no specific year is featured (all-time): the headline aggregates
    # every training rather than collapsing to the current year.
    @featured_year_value = featured_year
    @funder = funder
  end

  def columns
    @columns ||= @events.map { |event| Column.new(event: event, dashboard: EventDashboard.new(event, scholarship_donor: @funder)) }
  end

  def any?
    columns.any?
  end

  # Calendar-year groups, newest first. Trainings without a start date fall under
  # a nil year that sorts last; each year's columns read chronologically.
  def years
    @years ||= columns
      .group_by(&:year)
      .map { |year, year_columns| YearGroup.new(year: year, columns: sorted(year_columns), in_progress: year == @current_year) }
      .sort_by { |group| [ group.year ? 0 : 1, -(group.year || 0) ] }
  end

  # The group whose figures lead the KPI strip: the filtered/navigated-from year,
  # falling back to the most recent year present. When no year is featured
  # (all-time), an aggregate of every training so the headline isn't year-scoped.
  def featured_year
    return all_trainings_group if @featured_year_value.nil?
    years_by_value[@featured_year_value] || years.first
  end

  # A single group spanning every training, under a nil year so the KPI strip
  # reads "All trainings". Used as the all-time headline.
  def all_trainings_group
    @all_trainings_group ||= YearGroup.new(year: nil, columns: columns, in_progress: false)
  end

  # The most recent year-group strictly older than the featured one, for a
  # year-over-year delta. Nil when there's nothing older to compare against.
  def prior_year
    return nil unless featured_year&.year
    years.find { |group| group.year && group.year < featured_year.year }
  end

  # Stacked-column series by year, oldest to newest, in dollars — funded vs
  # unfunded scholarship money, for the hub card's mini chart.
  def chart_series
    ascending = years.reject { |group| group.year.nil? }.reverse
    {
      "Funded" => :funded_cents,
      "Unfunded" => :unfunded_cents
    }.map do |name, attribute|
      { name: name, data: ascending.map { |group| [ group.year.to_s, to_dollars(group.public_send(attribute)) ] } }
    end
  end

  private

  # A zeroed year group for a period with no trainings, so the summary card
  # renders 0 rather than blank.
  def empty_year_group(year)
    YearGroup.new(year: year, columns: [], in_progress: false)
  end

  def years_by_value
    @years_by_value ||= years.index_by(&:year)
  end

  def sorted(year_columns)
    year_columns.sort_by { |column| column.event.start_date || Time.zone.at(0) }
  end

  def to_dollars(cents)
    (cents / 100.0).round(2)
  end
end
