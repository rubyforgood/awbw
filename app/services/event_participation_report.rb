# Participation report: how many people completed each training, grouped by
# calendar year for an over-time view and annual-report figures. The sibling of
# EventRevenueReport — same year-grouped shape, but counting people instead of
# dollars.
#
# "Completed" = fully attended (EventRegistration status "attended"). The
# headline is UNIQUE PEOPLE (distinct registrants), because a person who attends
# two trainings in a year is one person we trained, not two. Seats (attended
# registration count) are additive and shown alongside when they differ, which
# is exactly where repeat attendees show up.
#
# The status detail (attended, partial/1-day, no-show, etc.) is a per-status
# registration count — each registration has exactly one status, so those sum
# cleanly and reconcile to total registrations.
class EventParticipationReport
  # Registration outcomes in display order — left to right across the per-event
  # detail row (attended first, then the rest of the attendance detail).
  STATUS_LABELS = {
    "attended" => "Attended",
    "registered" => "Registered",
    "transferred_in" => "Transferred in",
    "cancelled" => "Cancelled",
    "incomplete_attendance" => "Partial (1-day)",
    "no_show" => "No show",
    "transferred_out" => "Transferred out"
  }.freeze
  STATUSES = STATUS_LABELS.keys.freeze
  # The outcomes with no headline card/column of their own (registered, transfers,
  # cancellations). With attended, partial and no-show they total the registration
  # count, so the four buckets read across to Registrations. Matches the
  # registrants index "other" attendance filter.
  OTHER_STATUSES = (STATUSES - EventRegistration::NAMED_OUTCOME_STATUSES).freeze

  # Per-event outcome counts. Unique people equals attended seats here: the
  # [registrant_id, event_id] uniqueness index means a person holds one
  # registration per event, so people and seats only diverge once aggregated
  # across events (a year subtotal or the grand total).
  Row = Struct.new(:event, :status_counts, keyword_init: true) do
    def year
      event.start_date&.year
    end

    def count_for(status)
      status_counts.fetch(status, 0)
    end

    def attended_seats
      count_for("attended")
    end
    alias_method :unique_people, :attended_seats

    def total_registrations
      STATUSES.sum { |status| count_for(status) }
    end

    # Registrations still in play (registered / attended / partial / transferred
    # in) vs those that fell away (cancelled / no-show / transferred out) — the
    # headline counts active, with inactive shown alongside in parentheses.
    def active_registration_count
      EventRegistration::ACTIVE_STATUSES.sum { |status| count_for(status) }
    end

    def inactive_registration_count
      EventRegistration::INACTIVE_STATUSES.sum { |status| count_for(status) }
    end

    def count_other
      OTHER_STATUSES.sum { |status| count_for(status) }
    end
  end

  # Additive figures — seats and per-status counts — so a year subtotal or the
  # grand total is a plain sum over rows. Unique people is deliberately NOT here:
  # people don't add across events, so each level computes its own distinct count.
  module Aggregates
    def attended_seats
      rows.sum(&:attended_seats)
    end

    def count_for(status)
      rows.sum { |row| row.count_for(status) }
    end

    def total_registrations
      rows.sum(&:total_registrations)
    end

    def active_registration_count
      rows.sum(&:active_registration_count)
    end

    def inactive_registration_count
      rows.sum(&:inactive_registration_count)
    end

    def count_other
      rows.sum(&:count_other)
    end
  end

  # One calendar year of events, with its rows, additive subtotals, and its own
  # distinct-people count (passed in — it can't be summed from the rows).
  YearGroup = Struct.new(:year, :rows, :unique_people, :in_progress, keyword_init: true) do
    include Aggregates
  end

  include Aggregates
  include ReportPeriods

  def initialize(events, current_year: Date.current.year, featured_year: nil)
    @events = events.to_a
    @current_year = current_year
    # nil means no specific year is featured (all-time): the headline aggregates
    # every event rather than collapsing to the current year.
    @featured_year_value = featured_year
  end

  def rows
    @rows ||= @events.map do |event|
      Row.new(event: event, status_counts: status_counts_by_event.fetch(event.id, {}))
    end
  end

  def any?
    rows.any?
  end

  # Calendar-year groups, newest first, each with a subtotal. Events without a
  # start date fall under a nil year that sorts last.
  def years
    @years ||= rows
      .group_by(&:year)
      .map do |year, year_rows|
        YearGroup.new(
          year: year,
          rows: year_rows,
          unique_people: unique_people_by_year.fetch(year, 0),
          in_progress: year == @current_year
        )
      end
      .sort_by { |group| [ group.year ? 0 : 1, -(group.year || 0) ] }
  end

  # Distinct people who attended across every event in scope. Its own query, not
  # a sum of the year subtotals, because people aren't additive across years.
  def unique_people
    @unique_people ||= unique_attended_people
  end

  # The group whose figures lead the KPI strip: the filtered/navigated-from year,
  # falling back to the most recent year present. When no year is featured
  # (all-time), an aggregate of every event so the headline isn't year-scoped.
  def featured_year
    return all_events_group if @featured_year_value.nil?
    years_by_value[@featured_year_value] || years.first
  end

  # A single group spanning every event, under a nil year so the headline reads
  # "All events". unique_people is the distinct all-scope count (not a sum of
  # year subtotals). Used as the all-time headline.
  def all_events_group
    @all_events_group ||= YearGroup.new(year: nil, rows: rows, unique_people: unique_people, in_progress: false)
  end

  # The most recent year-group strictly older than the featured one, for a
  # year-over-year delta. Nil when there's nothing older to compare against.
  def prior_year
    return nil unless featured_year&.year
    years.find { |group| group.year && group.year < featured_year.year }
  end

  # The reach of the scoped registrants: how many distinct organizations,
  # sectors, states, countries and cities they span, for a given calendar year
  # (nil = every year in scope). Read "via registrants", like the event
  # dashboard's breakdown cards. States/countries come from registrant addresses;
  # cities come from the linked organizations' addresses.
  Demographics = Struct.new(:organizations, :sectors, :states, :countries, :cities, keyword_init: true)

  def demographics(year: nil)
    registrations = active_registrations(year: year)
    person_ids = registrations.distinct.pluck(:registrant_id)
    organization_ids = EventRegistrationOrganization
      .where(event_registration_id: registrations.select(:id))
      .distinct
      .pluck(:organization_id)
    addresses = Address.active
      .where(addressable_type: "Person", addressable_id: person_ids)
      .pluck(:state, :country)
    Demographics.new(
      organizations: organization_ids.size,
      sectors: SectorableItem.where(sectorable_type: "Person", sectorable_id: person_ids).distinct.count(:sector_id),
      states: addresses.map(&:first).reject(&:blank?).uniq.size,
      countries: addresses.map(&:last).reject(&:blank?).uniq.size,
      cities: Address.active
        .where(addressable_type: "Organization", addressable_id: organization_ids)
        .where.not(city: [ nil, "" ])
        .distinct
        .count(:city)
    )
  end

  # Distinct attended people split by whether the event is a facilitator
  # training, for a given calendar year (nil = every year in scope). Someone who
  # attends both a training and a non-training in the period is counted in each
  # bucket, so the two can sum to more than the combined unique_people total.
  def training_split(year: nil)
    {
      trainings: unique_attended_people(year: year, trainings: true),
      non_trainings: unique_attended_people(year: year, trainings: false)
    }
  end

  # Active registration counts split by whether the event is a facilitator
  # training, for a given calendar year (nil = every year in scope). Matches the
  # headline (active only); registrations are additive, so this is a plain sum
  # over the already-loaded rows.
  def registrations_split(year: nil)
    scoped = year ? rows.select { |row| row.year == year } : rows
    trainings, non_trainings = scoped.partition { |row| row.event.facilitator_training? }
    {
      trainings: trainings.sum(&:active_registration_count),
      non_trainings: non_trainings.sum(&:active_registration_count)
    }
  end

  # Stacked-column attendance-outcome series by year, oldest to newest — seats
  # (registration counts, one consistent unit) so the columns stack honestly.
  def chart_series
    ascending = years.reject { |group| group.year.nil? }.reverse
    {
      "Attended" => "attended",
      "Partial (1-day)" => "incomplete_attendance",
      "No show" => "no_show"
    }.map do |name, status|
      { name: name, data: ascending.map { |group| [ group.year.to_s, group.count_for(status) ] } }
    end
  end

  private

  # A zeroed year group for a period with no events, so the summary card renders
  # 0 rather than blank.
  def empty_year_group(year)
    YearGroup.new(year: year, rows: [], unique_people: 0, in_progress: false)
  end

  # Active registrations among the scoped events, optionally narrowed to a
  # calendar year — the people counted in the demographics breakdown.
  def active_registrations(year: nil)
    scope = EventRegistration.active.where(event_id: event_ids)
    scope = scope.joins(:event).where("YEAR(events.start_date) = ?", year) if year
    scope
  end

  # Distinct attended registrants among the scoped events, optionally narrowed to
  # a calendar year and/or facilitator-training status.
  def unique_attended_people(year: nil, trainings: nil)
    scope = EventRegistration.attended.where(event_id: event_ids)
    if year || !trainings.nil?
      scope = scope.joins(:event)
      scope = scope.where("YEAR(events.start_date) = ?", year) if year
      scope = scope.where(events: { facilitator_training: trainings }) unless trainings.nil?
    end
    scope.distinct.count(:registrant_id)
  end

  def event_ids
    @event_ids ||= @events.map(&:id)
  end

  def years_by_value
    @years_by_value ||= years.index_by(&:year)
  end

  # { event_id => { status => count } } from one grouped query, so no per-event
  # round trip and no Ruby readiness pass.
  def status_counts_by_event
    @status_counts_by_event ||= EventRegistration
      .where(event_id: event_ids)
      .group(:event_id, :status)
      .count
      .each_with_object({}) do |((event_id, status), count), map|
        (map[event_id] ||= {})[status] = count
      end
  end

  # { year => distinct attended people } in one grouped distinct query. A nil
  # start date extracts to a nil year, matching the "Undated" row group.
  def unique_people_by_year
    @unique_people_by_year ||= EventRegistration.attended
      .joins(:event)
      .where(event_id: event_ids)
      .group(Arel.sql("YEAR(events.start_date)"))
      .distinct
      .count(:registrant_id)
      .transform_keys { |year| year&.to_i }
  end
end
