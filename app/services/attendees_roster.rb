# Builds the per-registrant lookup maps the shared registrant roster partial
# (app/views/events/_registrant_roster.html.erb) reads — the cross-event
# counterpart to EventDashboard, which builds the same shape for a single event.
#
# Constructed with the already-filtered, already-paginated page of Person records
# in the current filter scope, so every map is scoped to just those
# rows (no whole-history scans). Columns are sourced from each person's own
# profile (sectors, age groups, affiliations, address); scholarship/CE/event
# columns come from their in-scope registrations.
class AttendeesRoster
  # Affiliation status taxonomy shown in the index's Affiliation status column and
  # offered as a filter, in display order.
  AFFILIATION_STATUSES = Affiliation::STATUSES

  # events / registrations: the event + registration scopes whose rows may be
  # counted — the index's current filters — so a person's Events/scholarship/CE
  # columns show what's in scope rather than their whole history, and never an
  # event the viewer isn't allowed to see.
  def initialize(people, events: Event.all, registrations: EventRegistration.attended)
    @people = people.to_a
    @events = events
    @registrations = registrations
  end

  attr_reader :people
  alias_method :registrants, :people

  def registrant_count
    people.size
  end

  # Each person's in-scope registrations, most recent event first, keyed by Person
  # id — the source for the roster's Events column.
  def event_registrations_by_registrant
    @event_registrations_by_registrant ||= scoped_registrations
      .group_by(&:registrant_id)
      .transform_values { |registrations| registrations.sort_by { |r| r.event.start_date || Date.new(0) }.reverse }
  end

  # The scholarship shown per person: the one from the most recent in-scope event where
  # they hold a scholarship. Keyed by Person id (matches EventDashboard's shape).
  def scholarship_by_recipient
    @scholarship_by_recipient ||= scholarship_registration_by_person
      .transform_values { |registration| scholarship_by_registration[registration.id] }
  end

  # [ event, participant slug ] the scholarship icon links to: the recipients page
  # of the most recent in-scope event where the person holds a scholarship, anchored to
  # their entry there.
  def scholarship_link_target(person)
    registration = scholarship_registration_by_person[person.id]
    return [ nil, nil ] unless registration
    [ registration.event, registration.slug ]
  end

  # The registration a person's roster row links to: their most recent in-scope
  # event. Mirrors EventDashboard#registration_link_target.
  def registration_link_target(person)
    registrations_for(person).first
  end

  # The event the person's shown scholarship comes from, keyed by Person id — lets
  # the cross-event index label which event funded it (it may not be the top-listed
  # one).
  def scholarship_event_by_registrant
    @scholarship_event_by_registrant ||= scholarship_registration_by_person.transform_values(&:event)
  end

  # The CE registration shown per person: the one from their most recent in-scope event
  # that has continuing education. Keyed by Person id.
  def ce_registration_by_registrant
    @ce_registration_by_registrant ||= ce_source_registration_by_registrant
      .transform_values { |registration| ce_registration_by_event_registration[registration.id] }
  end

  # The event the person's shown CE registration comes from, keyed by Person id.
  def ce_event_by_registrant
    @ce_event_by_registrant ||= ce_source_registration_by_registrant.transform_values(&:event)
  end

  # Primary sector name(s) per person, from their profile's primary sector tags.
  def primary_sector_names_by_registrant
    @primary_sector_names_by_registrant ||= people.to_h do |person|
      names = person.sectorable_items.select(&:is_primary?).filter_map { |item| item.sector&.name }.uniq.sort
      [ person.id, names ]
    end
  end

  # Primary age-group name(s) per person, from their profile.
  def primary_age_group_names_by_registrant
    @primary_age_group_names_by_registrant ||= people.to_h do |person|
      [ person.id, person.primary_age_groups.map(&:name) ]
    end
  end

  # Organizations linked on the listed people's in-scope registrations, name-ordered.
  # Mirrors the roster's Organization column, aggregated across all their events.
  def organizations
    # Preload affiliations: program-status classification (facilitator_status_on)
    # reads the loaded association rather than re-querying per org.
    @organizations ||= Organization.where(id: linked_org_ids_by_registrant.values.flatten.uniq).includes(:affiliations).order(:name)
  end

  # Linked-organization ids per person, uniqued across their in-scope registrations.
  def organization_ids_by_registrant
    linked_org_ids_by_registrant
  end

  # Distinct affiliation statuses (Active / Pending / Inactive) per person, in
  # display order — the index-only Affiliation status column and filter.
  def affiliation_statuses_by_registrant
    @affiliation_statuses_by_registrant ||= people.to_h do |person|
      statuses = person.affiliations.map { |affiliation| affiliation_status(affiliation) }.uniq
      [ person.id, AFFILIATION_STATUSES & statuses ]
    end
  end

  # Distinct program statuses of each person's affiliated organizations. This index
  # spans events, so there is no event date to anchor on — FacilitatorProgramStatus
  # falls back to the start of the current year and flags itself `year_anchored?`,
  # which the column's header caveat spells out.
  def program_statuses_by_registrant
    @program_statuses_by_registrant ||= organization_ids_by_registrant.transform_values do |organization_ids|
      organization_ids.filter_map { |organization_id| program_status_by_organization[organization_id] }.uniq(&:status)
    end
  end

  # Short location label per person from their active address: US state
  # abbreviation, otherwise the country.
  def location_label_by_registrant
    @location_label_by_registrant ||= Address
      .active
      .where(addressable_type: "Person", addressable_id: people.map(&:id))
      .order(primary: :desc, updated_at: :desc)
      .pluck(:addressable_id, :state, :country)
      .each_with_object({}) do |(person_id, state, country), map|
        next if map.key?(person_id)
        label = state.presence&.upcase || country.presence
        map[person_id] = label if label.present?
      end
  end

  private

  def registrations_for(person)
    event_registrations_by_registrant[person.id] || []
  end

  # The registration whose CE record the CE icon shows, per person: their most
  # recent in-scope event that has continuing education.
  def ce_source_registration_by_registrant
    @ce_source_registration_by_registrant ||= people.each_with_object({}) do |person, map|
      registration = registrations_for(person).find { |r| ce_registration_by_event_registration[r.id] }
      map[person.id] = registration if registration
    end
  end

  def scoped_registrations
    @scoped_registrations ||= @registrations
      .where(registrant_id: people.map(&:id), event_id: @events.select(:id))
      .includes(:event)
      .to_a
  end

  def registration_ids
    @registration_ids ||= scoped_registrations.map(&:id)
  end

  # The registration whose recipients-page entry the scholarship icon links to,
  # per person: the most recent in-scope event where they hold a scholarship.
  def scholarship_registration_by_person
    @scholarship_registration_by_person ||= people.each_with_object({}) do |person, map|
      registration = registrations_for(person).find { |r| scholarship_by_registration[r.id] }
      map[person.id] = registration if registration
    end
  end

  # Scholarship per funded registration id (first wins), across the page's
  # in-scope registrations.
  def scholarship_by_registration
    @scholarship_by_registration ||= Scholarship
      .joins(:allocation)
      .where(allocations: { allocatable_type: "EventRegistration", allocatable_id: registration_ids })
      .includes(:allocation)
      .group_by { |scholarship| scholarship.allocation.allocatable_id }
      .transform_values(&:first)
  end

  # First CE registration per in-scope registration id.
  def ce_registration_by_event_registration
    @ce_registration_by_event_registration ||= ContinuingEducationRegistration
      .where(event_registration_id: registration_ids)
      .group_by(&:event_registration_id)
      .transform_values(&:first)
  end

  # Organization ids linked on each person's in-scope registrations
  # (EventRegistrationOrganization), uniqued per person.
  def linked_org_ids_by_registrant
    @linked_org_ids_by_registrant ||= EventRegistrationOrganization
      .joins(:event_registration)
      .where(event_registration_id: registration_ids)
      .pluck(Arel.sql("event_registrations.registrant_id"), :organization_id)
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(registrant_id, organization_id), map|
        map[registrant_id] << organization_id unless map[registrant_id].include?(organization_id)
      end
  end

  def affiliation_status(affiliation)
    affiliation.status_on
  end

  # No event to anchor on here (the index spans them), so the status falls back to
  # the start of the current year — see FacilitatorProgramStatus.
  def program_status_by_organization
    @program_status_by_organization ||= organizations.to_h do |organization|
      [ organization.id, organization.facilitator_program_status ]
    end
  end
end
