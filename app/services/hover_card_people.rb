# Loads each person a feed page names with everything their facilitator hover
# card reads, keyed by id, so the page costs the same queries however many people
# it names. Keyed by id because one person reaches the page as several objects
# (a registrant on one row, a notification's person on another).
class HoverCardPeople
  ASSOCIATIONS = [
    :user,
    { affiliations: { organization: :affiliations } },
    { event_registrations: :event },
    { memberships: { membership_invoices: :allocations } }
  ].freeze

  def initialize(ids)
    @ids = ids.compact.uniq
  end

  def by_id
    return {} if @ids.empty?

    Person.where(id: @ids).includes(ASSOCIATIONS).index_by(&:id)
  end
end
