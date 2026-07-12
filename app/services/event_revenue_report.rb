# Revenue report for nonprofit CEOs: how much real money came in, how much the
# org subsidized from its own pocket, and the net — per event, grouped by
# calendar year for an over-time view and annual-report figures.
#
# Money in   = registration payments collected + projected CE + grant-funded
#              scholarships (grant money the org received).
# Org subsidy = unfunded scholarships + discounts (cost the org absorbs).
# Net         = money in - org subsidy.
#
# Projected CE is the CE fees owed across active registrants (each CE
# registration's own cost), flagged in the UI. It's counted in money in (and
# therefore net) per the report's definition, and treated as outstanding — CE
# payments collected aren't netted out here yet.
class EventRevenueReport
  # Raw per-event component figures, with the bucket totals derived from them.
  Row = Struct.new(
    :event,
    :registration_payments_cents,
    :ce_projected_cents,
    :funded_scholarship_cents,
    :unfunded_scholarship_cents,
    :discount_cents,
    :registration_outstanding_cents,
    keyword_init: true
  ) do
    # Fees actually collected: registration payments plus CE paid. CE payments
    # aren't netted here yet, so the CE portion is $0 today.
    def fees_cents
      registration_payments_cents
    end

    # Fees still owed: unpaid registration cost plus projected CE (none of which
    # is collected yet).
    def outstanding_cents
      registration_outstanding_cents + ce_projected_cents
    end

    # Money that's in or counted toward revenue: collected fees plus grant-funded
    # scholarships. Excludes outstanding (not yet paid) and org subsidy.
    def money_in_cents
      fees_cents + funded_scholarship_cents
    end

    def org_subsidy_cents
      unfunded_scholarship_cents + discount_cents
    end

    # Net = collected fees + funded scholarships − org subsidy.
    def net_cents
      money_in_cents - org_subsidy_cents
    end

    # What the event nets once everything owed is collected (net plus outstanding).
    def total_expected_cents
      net_cents + outstanding_cents
    end

    def year
      event.start_date&.year
    end
  end

  # The figures that get summed — raw components plus derived buckets — so a year
  # subtotal or the grand total is just a sum over rows.
  SUMMABLE = %i[
    registration_payments_cents ce_projected_cents funded_scholarship_cents
    unfunded_scholarship_cents discount_cents registration_outstanding_cents
    fees_cents outstanding_cents money_in_cents org_subsidy_cents net_cents total_expected_cents
  ].freeze

  module Summable
    SUMMABLE.each do |attribute|
      define_method(attribute) { rows.sum { |row| row.public_send(attribute) } }
    end
  end

  # One calendar year of events, with its rows and summed subtotals.
  YearGroup = Struct.new(:year, :rows, :in_progress, keyword_init: true) do
    include Summable
  end

  include Summable

  def initialize(events, current_year: Date.current.year, featured_year: nil)
    @events = events
    @current_year = current_year
    @featured_year_value = featured_year || current_year
  end

  def rows
    @rows ||= @events.map { |event| build_row(event) }
  end

  def any?
    rows.any?
  end

  # Calendar-year groups, newest first, each with a subtotal. Events without a
  # start date fall under a nil year that sorts last.
  def years
    @years ||= rows
      .group_by(&:year)
      .map { |year, year_rows| YearGroup.new(year: year, rows: year_rows, in_progress: year == @current_year) }
      .sort_by { |group| [ group.year ? 0 : 1, -(group.year || 0) ] }
  end

  # The year whose figures lead the KPI strip: the year navigated from (the event
  # clicked) or the current year. Falls back to the most recent year present when
  # that year has no events.
  def featured_year
    years_by_value[@featured_year_value] || years.first
  end

  # The most recent year-group strictly older than the featured one, for a
  # year-over-year delta. Nil when there's nothing older to compare against.
  def prior_year
    return nil unless featured_year&.year
    years.find { |group| group.year && group.year < featured_year.year }
  end

  # Stacked-column series by year, oldest to newest, in dollars — for the
  # Chartkick trend chart. Fees + grant-funded scholarships make up money in;
  # org subsidy stacks on top. Funded scholarships are broken out so grant-backed
  # revenue is visible separately.
  def chart_series
    ascending = years.reject { |group| group.year.nil? }.reverse
    {
      "Fees" => :fees_cents,
      "Funded scholarships" => :funded_scholarship_cents,
      "Org subsidy" => :org_subsidy_cents
    }.map do |name, attribute|
      { name: name, data: ascending.map { |group| [ group.year.to_s, to_dollars(group.public_send(attribute)) ] } }
    end
  end

  private

  def years_by_value
    @years_by_value ||= years.index_by(&:year)
  end

  def build_row(event)
    dashboard = EventDashboard.new(event)
    Row.new(
      event: event,
      registration_payments_cents: dashboard.received_cents,
      ce_projected_cents: ce_projected_cents_for(event),
      funded_scholarship_cents: dashboard.funded_scholarship_cents,
      unfunded_scholarship_cents: dashboard.unfunded_scholarship_cents,
      discount_cents: dashboard.discount_cents,
      registration_outstanding_cents: dashboard.outstanding_cents
    )
  end

  # Projected CE revenue: the CE fees owed across this event's active registrants
  # — each ContinuingEducationRegistration's own cost. Treated as outstanding, not
  # netted against any CE payments collected.
  def ce_projected_cents_for(event)
    ContinuingEducationRegistration
      .joins(:event_registration)
      .where(event_registrations: { event_id: event.id, status: EventRegistration::ACTIVE_STATUSES })
      .sum(:cost_cents)
  end

  def to_dollars(cents)
    (cents / 100.0).round(2)
  end
end
