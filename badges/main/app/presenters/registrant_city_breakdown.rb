# Groups an event's registrants by the city of the organization linked on their
# registration, counting distinct registrants and scholarship recipients per
# city. Powers the shared "Registrants by city" breakdown on the event
# background dashboard and the scholarship-recipients page. Pure/in-memory so
# EventDashboard feeds it already-plucked data (see [[event_dashboard]]).
#
# A registrant linked to orgs in two cities counts under each; the "Unknown"
# bucket (a linked org with no city on file) always sorts last.
class RegistrantCityBreakdown
  UNKNOWN_LABEL = "Unknown".freeze

  Row = Struct.new(:city, :registrant_count, :scholarship_count, :registrant_ids, :scholarship_recipient_ids, keyword_init: true)

  # org_registrant_pairs:       [ [ organization_id, person_id ], ... ], one per
  #                             organization linked on a registration.
  # city_by_org:                { organization_id => "City, State" }; a missing
  #                             entry means that org has no city ⇒ Unknown.
  # scholarship_recipient_ids:  person ids awarded a scholarship this event.
  def initialize(org_registrant_pairs:, city_by_org:, scholarship_recipient_ids:)
    @org_registrant_pairs = org_registrant_pairs
    @city_by_org = city_by_org
    @scholarship_recipient_ids = scholarship_recipient_ids.to_set
  end

  # Rows sorted by registrant count descending, then city name; Unknown last.
  def rows
    @rows ||= registrant_ids_by_city
      .map do |city, person_ids|
        scholarship_ids = person_ids.select { |id| @scholarship_recipient_ids.include?(id) }
        Row.new(
          city: city,
          registrant_count: person_ids.size,
          scholarship_count: scholarship_ids.size,
          registrant_ids: person_ids.to_a,
          scholarship_recipient_ids: scholarship_ids
        )
      end
      .sort_by { |row| [ row.city == UNKNOWN_LABEL ? 1 : 0, -row.registrant_count, row.city.downcase ] }
  end

  def city_count
    registrant_ids_by_city.size
  end

  def any?
    registrant_ids_by_city.any?
  end

  private

  def registrant_ids_by_city
    @registrant_ids_by_city ||= @org_registrant_pairs.each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |(org_id, person_id), map|
      city = @city_by_org[org_id].presence || UNKNOWN_LABEL
      map[city] << person_id
    end
  end
end
