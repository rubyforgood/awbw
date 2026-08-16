# Program-status report: how many organizations were New / Ongoing / Reinstated at
# each facilitator training, grouped by calendar year — the figures behind annual
# reporting. The sibling of EventRevenueReport / EventParticipationReport /
# EventScholarshipReport: same year-grouped shape, counting organizations.
#
# Every verdict comes from FacilitatorProgramStatus as of the training's own start
# date (ADR-0001 D4), so a row here says exactly what that event's dashboard, its
# onboarding matrix and the org's profile chip say.
#
# TWO WAYS TO ADD THEM UP, and they answer different questions:
#
#   * Org-events (the row and year totals) — one count per organization PER
#     training. An org that attended three trainings in a year counts three times.
#     This is the "how many program starts did each training represent" figure.
#   * Distinct organizations (#distinct_status_counts) — each organization counted
#     once for the period, classified at the EARLIEST training it appeared at. This
#     is the "how many distinct programs did we touch this year, and what were they
#     when we first saw them" figure.
#
# Give it a collection of (decorated) facilitator-training events.
class EventProgramStatusReport
  STATUSES = FacilitatorProgramStatus::STATUSES

  # One training's column: the organizations represented at it, each with its
  # status as of that training's start date, keyed by organization id.
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

    # Each organization counted ONCE for the period, classified at the earliest
    # training it appeared at, keyed by status. Reconciles against the summed row
    # above: distinct_organization_count <= organization_count, the difference
    # being orgs that attended more than one training in the period.
    def distinct_status_counts
      @distinct_status_counts ||= first_status_by_organization
        .values
        .each_with_object(STATUSES.index_with(0)) { |status, counts| counts[status.status] += 1 }
    end

    def distinct_organization_count = first_status_by_organization.size
    def distinct_new_count = distinct_status_counts[:new]
    def distinct_ongoing_count = distinct_status_counts[:ongoing]
    def distinct_reinstated_count = distinct_status_counts[:reinstated]

    # True when at least one organization appears at more than one training in the
    # period, i.e. the two ways of adding up disagree — which is when the view
    # needs to say so.
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

  # One column per training, each carrying its organizations' statuses. Loads the
  # org links for every training at once and the orgs with their affiliations at
  # once, then classifies in memory — a fixed number of queries however many
  # trainings are in scope.
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

  # Stacked-column series by year, oldest to newest — org-events per status, for
  # the reports hub card's mini chart.
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

  # Organization ids represented at each training, keyed by event id. "Represented"
  # is the same population the event dashboard counts: organizations linked to an
  # active registration.
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
end
