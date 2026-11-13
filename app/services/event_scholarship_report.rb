# Scholarship report: scholarship dollars and award counts (funded vs unfunded)
# per facilitator training, grouped by calendar year. The sibling of
# EventRevenueReport / EventParticipationReport — same year-grouped shape and
# reports-hub period card, but counting scholarships.
#
# Funded vs unfunded follows the app-wide convention (see EventDashboard):
# funded = backed by an external grant; unfunded = no grant, or a grant the org
# (AWBW) self-funded. Alongside the money it carries a trainee headcount —
# people who ATTENDED — split by delivery format: scheduled instructor-led
# sessions total under "Live" and self-paced ones (event.on_demand?) under
# "On-demand".
#
# Give it a collection of (decorated) facilitator-training events.
class EventScholarshipReport
  # One training's column. Sources every figure from EventScholarshipFigures, which
  # mirrors EventDashboard's funded/unfunded and attendance conventions (held by a
  # parity spec) but loads all events in a fixed number of queries.
  Column = Struct.new(:event, :figures, keyword_init: true) do
    def funded_cents = figures.funded_cents
    def unfunded_cents = figures.unfunded_cents
    def scholarship_cents = figures.scholarship_cents

    def funded_count = figures.funded_count
    def unfunded_count = figures.unfunded_count
    def scholarship_count = figures.scholarship_count

    # Trainees who fully attended (registration status "attended"), and — reported
    # beside it, never folded in — those recorded as partial.
    def attended_count = figures.attended_count
    def incomplete_count = figures.incomplete_count

    # Per-recipient scholarship breakdown for the row's expander: the funded /
    # unfunded recipients (name-sorted Person records) and their dollars keyed by
    # Person id. A recipient can appear in one split, both, or neither.
    def funded_recipients = figures.funded_recipients
    def unfunded_recipients = figures.unfunded_recipients
    def funded_cents_by_recipient = figures.funded_cents_by_recipient
    def unfunded_cents_by_recipient = figures.unfunded_cents_by_recipient

    def on_demand? = event.on_demand?
    def label = event.compact_label
    def date_label = event.start_date? ? event.short_date_range : nil
    def year = event.start_date&.year
  end

  # The additive figures — summed across a year's columns for its totals, and
  # across every column for the all-time total.
  SUMMABLE = %i[
    funded_cents unfunded_cents scholarship_cents
    funded_count unfunded_count scholarship_count attended_count incomplete_count
  ].freeze

  module Aggregates
    SUMMABLE.each do |attribute|
      define_method(attribute) { columns.sum(&attribute) }
    end

    # Attendance split by delivery format — these sum to attended_count.
    def live_attended_count = columns.reject(&:on_demand?).sum(&:attended_count)
    def on_demand_attended_count = columns.select(&:on_demand?).sum(&:attended_count)

    # Distinct scholarship recipients who attended (registration status
    # "attended") — people, not seats: someone who holds a scholarship across two
    # of these trainings counts once. Split by delivery format (a person attending
    # both formats counts in each split, so the two need not sum to the total).
    def recipients_attended_count = distinct_attended_recipient_count(columns.map { |column| column.event.id })
    def live_recipients_attended_count = distinct_attended_recipient_count(columns.reject(&:on_demand?).map { |column| column.event.id })
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
    @columns ||= @events.map { |event| Column.new(event: event, figures: figures.for(event)) }
  end

  # One organization whose trainees received scholarships across the trainings in
  # scope, with where its program is.
  OrganizationRow = Struct.new(:organization, :figures, :locations, keyword_init: true) do
    def funded_cents = figures.funded_cents
    def unfunded_cents = figures.unfunded_cents
    def scholarship_cents = figures.scholarship_cents
    def award_count = figures.award_count
    def recipient_count = figures.recipient_count
  end

  # Organizations whose trainees received scholarships, name-sorted. See
  # EventScholarshipFigures#by_organization for how awards are credited, and
  # #locations_for for each row's locations.
  def organization_rows
    @organization_rows ||= begin
      by_organization = figures.by_organization
      organizations = Organization.includes(:addresses).where(id: by_organization.keys.compact)
      organizations
        .map do |organization|
          org_figures = by_organization[organization.id]
          OrganizationRow.new(organization: organization, figures: org_figures,
            locations: locations_for(organization, org_figures.recipient_ids))
        end
        .sort_by { |row| row.organization.name.to_s.downcase }
    end
  end

  # Scholarships on registrations linked to no organization (nil when none), so
  # the organization list reconciles with the totals.
  def unaffiliated_scholarships
    figures.by_organization[nil]
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

  # "City, ST" labels, uniqued, for where an org's recipients facilitate. From
  # the recipients' facilitator affiliations with the org that were in effect
  # during the report's timeframe — active, since ended, or upcoming alike (job
  # affiliations don't count): each contributes the org address picked on it
  # (even one since made inactive), and one with no address picked contributes
  # all the org's active addresses. With no such affiliation at all, the org's
  # active addresses stand in.
  def locations_for(organization, recipient_ids)
    picked_ids = affiliation_address_ids_by_org_person
      .slice(*recipient_ids.map { |person_id| [ organization.id, person_id ] })
      .values.flatten
    picked = picked_ids.filter_map { |id| affiliation_addresses_by_id[id] if id }
    # An affiliation with no address picked (or one since deleted) — or no
    # affiliation at all — brings in the org's active addresses.
    unpicked = picked_ids.empty? || picked.size < picked_ids.size
    addresses = picked + (unpicked ? organization.addresses.reject(&:inactive?) : [])
    addresses
      .filter_map { |address| [ address.city, address.state ].compact_blank.join(", ").presence }
      .uniq(&:downcase)
      .sort
  end

  # { [ organization_id, person_id ] => [ organization_address_id or nil, ... ] }
  # for the facilitator affiliations of every credited recipient with every
  # listed org — nil where no address was picked.
  def affiliation_address_ids_by_org_person
    @affiliation_address_ids_by_org_person ||= begin
      by_organization = figures.by_organization.except(nil)
      window = report_window
      scope = Affiliation.facilitators
      # In effect at some point in the report's timeframe, judged by dates (not the
      # inactive flag, which reflects today) — so a recipient who has since left
      # still shows where they facilitated then.
      if window
        scope = scope
          .where("affiliations.start_date IS NULL OR affiliations.start_date <= ?", window.last)
          .where("affiliations.end_date IS NULL OR affiliations.end_date >= ?", window.first)
      end
      scope
        .where(organization_id: by_organization.keys, person_id: by_organization.values.flat_map { |f| f.recipient_ids.to_a }.uniq)
        .pluck(:organization_id, :person_id, :organization_address_id)
        .group_by { |organization_id, person_id, _| [ organization_id, person_id ] }
        .transform_values { |rows| rows.map(&:last) }
    end
  end

  # The report's timeframe: the selected calendar year, else (all time) the span
  # of the events in scope. Nil when no event has a date.
  def report_window
    return Date.new(@featured_year_value, 1, 1)..Date.new(@featured_year_value, 12, 31) if @featured_year_value

    starts = @events.filter_map { |event| event.start_date&.to_date }
    ends = @events.filter_map { |event| (event.end_date || event.start_date)&.to_date }
    starts.min..ends.max if starts.any?
  end

  def affiliation_addresses_by_id
    @affiliation_addresses_by_id ||= Address.where(id: affiliation_address_ids_by_org_person.values.flatten.compact.uniq).index_by(&:id)
  end

  def figures
    @figures ||= EventScholarshipFigures.new(@events, funder: @funder)
  end

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
