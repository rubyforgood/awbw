# Organizations by program status at each facilitator training, grouped by calendar
# year — the figures behind annual reporting. Sibling of EventRevenueReport /
# EventParticipationReport / EventScholarshipReport. Takes decorated events.
#
# Counted two ways, because they answer different questions (ADR-0001 D9):
# the row and year totals count an org once PER training, while
# #distinct_status_counts counts it once for the period, at its earliest training.
class EventProgramStatusReport
  STATUSES = FacilitatorProgramStatus::STATUSES

  # One training's organizations and their statuses, keyed by organization id.
  Column = Struct.new(:event, :statuses, keyword_init: true) do
    def new_count = count_of(:new)
    def ongoing_count = count_of(:ongoing)
    def reinstated_count = count_of(:reinstated)
    def organization_count = statuses.size

    def label = event.compact_label
    def date_label = event.start_date? ? event.short_date_range : nil
    def year = event.start_date&.year
    def anchor_date = event.start_date&.to_date

    def count_of(status) = statuses.count { |_id, program_status| program_status.status == status }
  end

  # The additive figures — summed across a year's columns for its totals, and
  # across every column for the all-time total.
  SUMMABLE = %i[ new_count ongoing_count reinstated_count organization_count ].freeze

  module Aggregates
    SUMMABLE.each do |attribute|
      define_method(attribute) { columns.sum(&attribute) }
    end

    def distinct_status_counts
      @distinct_status_counts ||= first_status_by_organization
        .values
        .each_with_object(STATUSES.index_with(0)) { |status, counts| counts[status.status] += 1 }
    end

    def distinct_organization_count = first_status_by_organization.size
    def distinct_new_count = distinct_status_counts[:new]
    def distinct_ongoing_count = distinct_status_counts[:ongoing]
    def distinct_reinstated_count = distinct_status_counts[:reinstated]

    # The two ways of adding up disagree, which is when the view needs to say so.
    def repeat_organizations? = organization_count != distinct_organization_count

    private

    def first_status_by_organization
      @first_status_by_organization ||= chronological_columns.each_with_object({}) do |column, statuses|
        column.statuses.each { |organization_id, status| statuses[organization_id] ||= status }
      end
    end

    def chronological_columns
      columns.sort_by { |column| column.event.start_date || Time.zone.at(0) }
    end
  end

  # One calendar year of trainings, with its columns and totals.
  YearGroup = Struct.new(:year, :columns, :in_progress, keyword_init: true) do
    include Aggregates
  end

  include Aggregates
  include ReportPeriods

  def initialize(events, current_year: Date.current.year, featured_year: nil)
    @events = events.to_a
    @current_year = current_year
    # nil means no specific year is featured (all-time): the headline aggregates
    # every training rather than collapsing to the current year.
    @featured_year_value = featured_year
  end

  # Loads every training's org links, then those orgs with their affiliations, and
  # classifies in memory — a fixed number of queries however many trainings.
  def columns
    @columns ||= begin
      links = organization_ids_by_event
      organizations = Organization.where(id: links.values.flatten.uniq).includes(:affiliations).index_by(&:id)
      @events.map do |event|
        statuses = (links[event.id] || []).to_h do |organization_id|
          [ organization_id, organizations.fetch(organization_id).facilitator_program_status(as_of: event.start_date&.to_date) ]
        end
        Column.new(event: event, statuses: statuses)
      end
    end
  end

  def any? = columns.any?

  # Newest year first; undated trainings fall under a nil year that sorts last.
  def years
    @years ||= columns
      .group_by(&:year)
      .map { |year, year_columns| YearGroup.new(year: year, columns: sorted(year_columns), in_progress: year == @current_year) }
      .sort_by { |group| [ group.year ? 0 : 1, -(group.year || 0) ] }
  end

  # The filtered/navigated-from year, or every training when none is featured.
  def featured_year
    return all_trainings_group if @featured_year_value.nil?
    years_by_value[@featured_year_value] || years.first
  end

  def all_trainings_group
    @all_trainings_group ||= YearGroup.new(year: nil, columns: columns, in_progress: false)
  end

  # The most recent year older than the featured one, for a year-over-year delta.
  def prior_year
    return nil unless featured_year&.year
    years.find { |group| group.year && group.year < featured_year.year }
  end

  # Stacked-column series by year, oldest to newest, for the hub card's mini chart.
  def chart_series
    ascending = years.reject { |group| group.year.nil? }.reverse
    {
      "New" => :new_count,
      "Ongoing" => :ongoing_count,
      "Reinstated" => :reinstated_count
    }.map do |name, attribute|
      { name: name, data: ascending.map { |group| [ group.year.to_s, group.public_send(attribute) ] } }
    end
  end

  private

  # "Represented" is the population the event dashboard counts: organizations
  # linked to an active registration.
  def organization_ids_by_event
    event_ids = @events.map(&:id)
    return {} if event_ids.empty?

    EventRegistrationOrganization
      .joins(:event_registration)
      .merge(EventRegistration.active)
      .where(event_registrations: { event_id: event_ids })
      .pluck(Arel.sql("event_registrations.event_id"), :organization_id)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }
  end

  # Lets the summary card render 0 rather than blank for a trainingless period.
  def empty_year_group(year)
    YearGroup.new(year: year, columns: [], in_progress: false)
  end

  def years_by_value
    @years_by_value ||= years.index_by(&:year)
  end

  def sorted(year_columns)
    year_columns.sort_by { |column| column.event.start_date || Time.zone.at(0) }
  end
end
