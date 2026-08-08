# Cross-event breakdown datasets for the training-attendees index charts — the
# aggregate counterpart to EventDashboard's breakdown methods, computed over the
# whole filtered attendee population (not one page). Method names/return shapes
# match EventDashboard so the shared _registrant_breakdowns partial reads either.
#
# Sourced from each person's profile (sectors, age groups, categories, addresses)
# and from the orgs/scholarships/CE tied to their attended-training registrations.
class TrainingAttendeesBreakdowns
  # US states/territories the atlas draws — international regions are excluded from
  # the States breakdown (they belong to Countries), mirroring EventDashboard.
  US_STATE_ABBREVIATIONS = %w[
    AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO
    MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY
    PR GU VI AS MP
  ].freeze

  def initialize(people)
    @people = people
  end

  def registrant_count
    person_ids.size
  end

  # --- Sectors ---------------------------------------------------------------

  def primary_sectors
    Sector.where(id: primary_sector_counts.keys).order(:name)
  end

  def primary_sector_counts
    @primary_sector_counts ||= distinct_person_counts(sector_rows.select { |_, _, primary| primary }) { |row| row[1] }
  end

  def sectors
    Sector.where(id: sector_counts.keys).order(:name)
  end

  def sector_counts
    @sector_counts ||= distinct_person_counts(sector_rows) { |row| row[1] }
  end

  # --- Age groups ------------------------------------------------------------

  def age_groups
    Category.age_ranges.where(id: age_group_counts.keys).ordered_by_position_and_name
  end

  def age_group_counts
    @age_group_counts ||= distinct_person_counts(age_rows.select { |_, _, primary| primary }) { |row| row[1] }
  end

  def all_age_groups
    Category.age_ranges.where(id: all_age_group_counts.keys).ordered_by_position_and_name
  end

  def all_age_group_counts
    @all_age_group_counts ||= distinct_person_counts(age_rows) { |row| row[1] }
  end

  # --- Locations -------------------------------------------------------------

  def state_counts
    @state_counts ||= active_addresses
      .where("UPPER(addresses.state) IN (?)", US_STATE_ABBREVIATIONS)
      .group(:state)
      .distinct
      .count(:addressable_id)
  end

  def country_counts
    @country_counts ||= active_addresses
      .where.not(country: [ nil, "" ])
      .group(:country)
      .distinct
      .count(:addressable_id)
  end

  def school_district_counts
    @school_district_counts ||= active_addresses
      .where.not(district: [ nil, "" ])
      .group(:district)
      .distinct
      .count(:addressable_id)
  end

  # --- Profile categories (life experiences / settings) ----------------------

  def life_experiences
    Category.where(id: life_experience_counts.keys).order(:name)
  end

  def life_experience_counts
    @life_experience_counts ||= category_counts("StoryPopulation")
  end

  def settings
    Category.where(id: settings_counts.keys).order(:name)
  end

  def settings_counts
    @settings_counts ||= category_counts("WorkshopEnvironment")
  end

  # --- Organizations + program status ----------------------------------------

  def organizations
    @organizations ||= Organization.where(id: org_registrant_pairs.map(&:first).uniq).order(:name)
  end

  def organization_counts
    @organization_counts ||= org_registrant_pairs
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq.size }
  end

  def scholarship_recipient_count_by_org
    recipient_ids = scholarship_recipient_ids.to_set
    org_registrant_pairs
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq.count { |person_id| recipient_ids.include?(person_id) } }
      .select { |_, count| count.positive? }
  end

  def program_status_counts
    @program_status_counts ||= program_status_by_organization.each_with_object({ new: 0, ongoing: 0, reinstated: 0 }) do |(_org_id, status), counts|
      counts[status] += 1 if counts.key?(status)
    end
  end

  # --- Scholarships + CE -----------------------------------------------------

  def scholarship_recipient_count
    scholarship_recipient_ids.size
  end

  def ce_registrant_ids
    @ce_registrant_ids ||= ContinuingEducationRegistration
      .joins(:event_registration)
      .where(event_registration_id: training_registration_ids)
      .distinct
      .pluck(Arel.sql("event_registrations.registrant_id"))
  end

  # --- Cities ----------------------------------------------------------------

  # Attendees grouped by the city of the organization linked on their attended-
  # training registrations, with scholarship recipients per city — the shared
  # "Registrants by city" breakdown, aggregated across all trainings.
  def registrant_city_breakdown
    @registrant_city_breakdown ||= RegistrantCityBreakdown.new(
      org_registrant_pairs: org_registrant_pairs,
      city_by_org: city_by_organization,
      scholarship_recipient_ids: scholarship_recipient_ids
    )
  end

  # --- Free-text "Other" sector responses ------------------------------------

  def other_sector_response_count
    other_sector_responses.map(&:owner_id).uniq.size
  end

  def other_sector_response_rows
    other_sector_responses
      .group_by(&:normalized_text)
      .map { |_normalized, responses| ids = responses.map(&:owner_id).uniq; [ responses.first.text, ids.size, ids ] }
      .sort_by { |text, count, _ids| [ -count, text.downcase ] }
  end

  private

  def person_ids
    # Strip any includes/order the caller attached: one of the roster's eager-loads
    # (age_range_categorizable_items) carries a scoped WHERE that would otherwise
    # turn `.ids` into a filtering JOIN and drop people with no age tag.
    @person_ids ||= @people.except(:includes, :eager_load, :preload, :order).ids
  end

  def training_registration_ids
    @training_registration_ids ||= EventRegistration
      .attended
      .joins(:event)
      .where(events: { facilitator_training: true }, registrant_id: person_ids)
      .pluck(:id)
  end

  def sector_rows
    @sector_rows ||= SectorableItem
      .where(sectorable_type: "Person", sectorable_id: person_ids)
      .pluck(:sectorable_id, :sector_id, :is_primary)
  end

  def age_rows
    @age_rows ||= CategorizableItem
      .joins(category: :category_type)
      .where(categorizable_type: "Person", categorizable_id: person_ids, category_types: { name: "AgeRange" })
      .pluck(:categorizable_id, :category_id, :is_primary)
  end

  def category_counts(category_type_name)
    CategorizableItem
      .joins(category: :category_type)
      .where(categorizable_type: "Person", categorizable_id: person_ids, category_types: { name: category_type_name })
      .distinct
      .group(:category_id)
      .count(:categorizable_id)
  end

  def active_addresses
    Address.active.where(addressable_type: "Person", addressable_id: person_ids)
  end

  def org_registrant_pairs
    @org_registrant_pairs ||= EventRegistrationOrganization
      .joins(:event_registration)
      .where(event_registration_id: training_registration_ids)
      .pluck(:organization_id, Arel.sql("event_registrations.registrant_id"))
  end

  def program_status_by_organization
    @program_status_by_organization ||= organizations.to_h do |organization|
      [ organization.id, organization.facilitator_status_on(Date.current) ]
    end
  end

  # "City, State" per linked organization, from its first active address (mirrors
  # EventDashboard#city_by_organization). Orgs with no active address are absent,
  # so their registrants fall into the breakdown's Unknown bucket.
  def city_by_organization
    org_ids = org_registrant_pairs.map(&:first).uniq
    Address.active
      .where(addressable_type: "Organization", addressable_id: org_ids)
      .order(:id)
      .pluck(:addressable_id, :city, :state)
      .each_with_object({}) do |(org_id, city, state), map|
        next if map.key?(org_id)
        label = [ city, state ].compact_blank.join(", ").presence
        map[org_id] = label if label
      end
  end

  def scholarship_recipient_ids
    @scholarship_recipient_ids ||= Scholarship
      .joins(:allocation)
      .where(allocations: { allocatable_type: "EventRegistration", allocatable_id: training_registration_ids })
      .distinct
      .pluck(:recipient_id)
  end

  def other_sector_responses
    @other_sector_responses ||= OtherResponse
      .sectors
      .visible
      .where(owner_type: "Person", owner_id: person_ids)
      .order(:id)
      .to_a
  end

  # Distinct-person count per key, grouping the given [ person_id, key, ... ] rows
  # by the block's key.
  def distinct_person_counts(rows)
    rows.group_by { |row| yield(row) }.transform_values { |grouped| grouped.map(&:first).uniq.size }
  end
end
