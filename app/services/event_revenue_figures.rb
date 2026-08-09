# Per-event money components for the revenue report, loaded for every event at
# once in a fixed number of grouped queries instead of an EventDashboard (and its
# ~8 queries) per event.
#
# The definitions mirror EventDashboard's — active registrations only, cost net of
# every allocation and floored at zero, payment allocations for cash collected —
# so a row in the report and that event's dashboard can't disagree. A parity spec
# holds the two together.
#
# One definition is broader than the dashboard's: discounts cover CE registrations
# too, not just event registrations. CE cost is only ever paid, discounted, or
# owed, so counting CE discounts as org subsidy is what keeps a discounted CE fee
# from vanishing from the report entirely.
class EventRevenueFigures
  Figures = Struct.new(
    :registration_payments_cents,
    :registration_outstanding_cents,
    :funded_scholarship_cents,
    :unfunded_scholarship_cents,
    :discount_cents,
    :ce_paid_cents,
    :ce_outstanding_cents,
    keyword_init: true
  )

  EMPTY = Figures.new(
    registration_payments_cents: 0,
    registration_outstanding_cents: 0,
    funded_scholarship_cents: 0,
    unfunded_scholarship_cents: 0,
    discount_cents: 0,
    ce_paid_cents: 0,
    ce_outstanding_cents: 0
  ).freeze

  # One person's share of a component, for the report's per-figure drilldowns.
  Contributor = Struct.new(:person, :cents, keyword_init: true)

  # The people behind each component figure, mirroring Figures — each list sums
  # to the matching cents total, so an expanded row reconciles with its subtotal.
  Breakdown = Struct.new(
    :registration_payments,
    :registration_outstanding,
    :funded_scholarships,
    :unfunded_scholarships,
    :discounts,
    :ce_paid,
    :ce_outstanding,
    keyword_init: true
  )

  EMPTY_BREAKDOWN = Breakdown.new(
    registration_payments: [],
    registration_outstanding: [],
    funded_scholarships: [],
    unfunded_scholarships: [],
    discounts: [],
    ce_paid: [],
    ce_outstanding: []
  ).freeze

  def initialize(events)
    @events = events.to_a
  end

  def for(event)
    figures_by_event_id.fetch(event.id, EMPTY)
  end

  # Per-person contributors behind each component figure for the event's
  # drilldowns. Loaded lazily (one extra Person query) so the plain totals stay
  # at their fixed query count when the breakdowns aren't needed.
  def breakdown_for(event)
    breakdowns_by_event_id.fetch(event.id, EMPTY_BREAKDOWN)
  end

  private

  # A grant counts as external funding only when it exists and the org didn't
  # donate it to itself (AWBW) — the in-memory form of Scholarship.externally_funded.
  def external_grant?(grant_id)
    grant_id.present? && !self_donated_grant_ids.include?(grant_id)
  end

  def self_donated_grant_ids
    @self_donated_grant_ids ||= Grant.self_donated_ids.to_set
  end

  def figures_by_event_id
    @figures_by_event_id ||= @events.to_h { |event| [ event.id, build(event) ] }
  end

  def breakdowns_by_event_id
    @breakdowns_by_event_id ||= @events.to_h { |event| [ event.id, build_breakdown(event) ] }
  end

  # Roll every component up per person from the same bulk-loaded rows as #build,
  # so a drilldown list and its subtotal are computed the same way. Registration
  # payments, outstanding, and both discount kinds key by the registration's
  # registrant; scholarships key by their recipient.
  def build_breakdown(event)
    registration_ids = registration_ids_by_event.fetch(event.id, [])
    cost_cents = event.cost_cents.to_i

    registration_payments = Hash.new(0)
    registration_outstanding = Hash.new(0)
    discounts = Hash.new(0)
    funded_scholarships = Hash.new(0)
    unfunded_scholarships = Hash.new(0)
    ce_paid = Hash.new(0)
    ce_outstanding = Hash.new(0)

    registration_ids.each do |id|
      registrant_id = registrant_id_by_registration[id]
      next unless registrant_id

      registration_payments[registrant_id] += registration_allocations[[ id, "Payment" ]].to_i
      registration_outstanding[registrant_id] += [ cost_cents - registration_allocated_total[id], 0 ].max
      discounts[registrant_id] += registration_allocations[[ id, "Discount" ]].to_i

      scholarship_rows_by_registration.fetch(id, []).each do |grant_id, amount_cents, recipient_id|
        recipient_id ||= registrant_id
        bucket = external_grant?(grant_id) ? funded_scholarships : unfunded_scholarships
        bucket[recipient_id] += amount_cents
      end

      ce_rows_by_registration.fetch(id, []).each do |ce_id, cost|
        ce_paid[registrant_id] += ce_allocations[[ ce_id, "Payment" ]].to_i
        ce_outstanding[registrant_id] += [ cost.to_i - ce_allocated_total[ce_id], 0 ].max
        discounts[registrant_id] += ce_allocations[[ ce_id, "Discount" ]].to_i
      end
    end

    Breakdown.new(
      registration_payments: contributors_from(registration_payments),
      registration_outstanding: contributors_from(registration_outstanding),
      funded_scholarships: contributors_from(funded_scholarships),
      unfunded_scholarships: contributors_from(unfunded_scholarships),
      discounts: contributors_from(discounts),
      ce_paid: contributors_from(ce_paid),
      ce_outstanding: contributors_from(ce_outstanding)
    )
  end

  # Turn a { person_id => cents } map into name-sorted Contributors, dropping
  # zero (and negative) shares so only people who actually moved the total show.
  def contributors_from(cents_by_person_id)
    cents_by_person_id
      .filter_map do |person_id, cents|
        next unless cents.positive?
        person = people_by_id[person_id]
        next unless person
        Contributor.new(person: person, cents: cents)
      end
      .sort_by { |contributor| contributor.person.name.downcase }
  end

  # Every registrant and scholarship recipient across the report, loaded once for
  # the drilldown lists' names and links.
  def people_by_id
    @people_by_id ||= Person.where(id: breakdown_person_ids).index_by(&:id)
  end

  def breakdown_person_ids
    recipient_ids = scholarship_rows_by_registration.values.flatten(1).map { |row| row[2] }
    (registrant_id_by_registration.values + recipient_ids).compact.uniq
  end

  def build(event)
    registration_ids = registration_ids_by_event.fetch(event.id, [])
    cost_cents = event.cost_cents.to_i
    ce_rows = registration_ids.flat_map { |id| ce_rows_by_registration.fetch(id, []) }
    scholarships = registration_ids.flat_map { |id| scholarship_rows_by_registration.fetch(id, []) }

    Figures.new(
      registration_payments_cents: registration_ids.sum { |id| registration_allocations[[ id, "Payment" ]].to_i },
      registration_outstanding_cents: registration_ids.sum { |id| [ cost_cents - registration_allocated_total[id], 0 ].max },
      funded_scholarship_cents: scholarships.sum { |grant_id, amount_cents| external_grant?(grant_id) ? amount_cents : 0 },
      unfunded_scholarship_cents: scholarships.sum { |grant_id, amount_cents| external_grant?(grant_id) ? 0 : amount_cents },
      discount_cents: registration_ids.sum { |id| registration_allocations[[ id, "Discount" ]].to_i } +
        ce_rows.sum { |ce_id, _cost| ce_allocations[[ ce_id, "Discount" ]].to_i },
      ce_paid_cents: ce_rows.sum { |ce_id, _cost| ce_allocations[[ ce_id, "Payment" ]].to_i },
      ce_outstanding_cents: ce_rows.sum { |ce_id, cost| [ cost.to_i - ce_allocated_total[ce_id], 0 ].max }
    )
  end

  # [ event_id, registration_id, registrant_id ] for every active registration in
  # the report — the basis for both the per-event grouping and the drilldowns'
  # registrant lookup, loaded in one query.
  def registration_rows
    @registration_rows ||= EventRegistration
      .active
      .where(event_id: @events.map(&:id))
      .pluck(:event_id, :id, :registrant_id)
  end

  # { event_id => [ registration_id, ... ] } across every event in the report.
  def registration_ids_by_event
    @registration_ids_by_event ||= registration_rows
      .each_with_object({}) { |(event_id, id, _registrant_id), map| (map[event_id] ||= []) << id }
  end

  # { registration_id => registrant_id (Person id) } for the drilldowns.
  def registrant_id_by_registration
    @registrant_id_by_registration ||= registration_rows
      .each_with_object({}) { |(_event_id, id, registrant_id), map| map[id] = registrant_id }
  end

  def registration_ids
    @registration_ids ||= registration_ids_by_event.values.flatten
  end

  # { registration_id => [ [ ce_registration_id, cost_cents ], ... ] }.
  def ce_rows_by_registration
    @ce_rows_by_registration ||= ContinuingEducationRegistration
      .where(event_registration_id: registration_ids)
      .pluck(:event_registration_id, :id, :cost_cents)
      .each_with_object({}) { |(registration_id, id, cost), map| (map[registration_id] ||= []) << [ id, cost ] }
  end

  # { registration_id => [ [ grant_id, amount_cents, recipient_id ], ... ] }. The
  # recipient id feeds the scholarship drilldowns; #build reads only the first two.
  def scholarship_rows_by_registration
    @scholarship_rows_by_registration ||= Scholarship
      .joins(:allocation)
      .where(allocations: { allocatable_type: "EventRegistration", allocatable_id: registration_ids })
      .pluck(Arel.sql("allocations.allocatable_id"), :grant_id, :amount_cents, :recipient_id)
      .each_with_object({}) { |(registration_id, grant_id, amount, recipient_id), map| (map[registration_id] ||= []) << [ grant_id, amount, recipient_id ] }
  end

  # { [ allocatable_id, source_type ] => cents } for each allocatable kind, plus
  # the same sums collapsed to { allocatable_id => cents } across every source.
  def registration_allocations
    @registration_allocations ||= allocation_sums("EventRegistration", registration_ids)
  end

  def ce_allocations
    @ce_allocations ||= allocation_sums("ContinuingEducationRegistration", ce_rows_by_registration.values.flatten(1).map(&:first))
  end

  def registration_allocated_total
    @registration_allocated_total ||= totals_by_allocatable(registration_allocations)
  end

  def ce_allocated_total
    @ce_allocated_total ||= totals_by_allocatable(ce_allocations)
  end

  def allocation_sums(allocatable_type, allocatable_ids)
    Allocation
      .where(allocatable_type: allocatable_type, allocatable_id: allocatable_ids)
      .group(:allocatable_id, :source_type)
      .sum(:amount)
  end

  def totals_by_allocatable(sums)
    sums.each_with_object(Hash.new(0)) { |((id, _source_type), amount), map| map[id] += amount }
  end
end
