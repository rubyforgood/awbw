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

  def initialize(events)
    @events = events.to_a
  end

  def for(event)
    figures_by_event_id.fetch(event.id, EMPTY)
  end

  private

  def figures_by_event_id
    @figures_by_event_id ||= @events.to_h { |event| [ event.id, build(event) ] }
  end

  def build(event)
    registration_ids = registration_ids_by_event.fetch(event.id, [])
    cost_cents = event.cost_cents.to_i
    ce_rows = registration_ids.flat_map { |id| ce_rows_by_registration.fetch(id, []) }
    scholarships = registration_ids.flat_map { |id| scholarship_rows_by_registration.fetch(id, []) }

    Figures.new(
      registration_payments_cents: registration_ids.sum { |id| registration_allocations[[ id, "Payment" ]].to_i },
      registration_outstanding_cents: registration_ids.sum { |id| [ cost_cents - registration_allocated_total[id], 0 ].max },
      funded_scholarship_cents: scholarships.sum { |grant_id, amount_cents| grant_id ? amount_cents : 0 },
      unfunded_scholarship_cents: scholarships.sum { |grant_id, amount_cents| grant_id ? 0 : amount_cents },
      discount_cents: registration_ids.sum { |id| registration_allocations[[ id, "Discount" ]].to_i } +
        ce_rows.sum { |ce_id, _cost| ce_allocations[[ ce_id, "Discount" ]].to_i },
      ce_paid_cents: ce_rows.sum { |ce_id, _cost| ce_allocations[[ ce_id, "Payment" ]].to_i },
      ce_outstanding_cents: ce_rows.sum { |ce_id, cost| [ cost.to_i - ce_allocated_total[ce_id], 0 ].max }
    )
  end

  # { event_id => [ registration_id, ... ] } across every event in the report.
  def registration_ids_by_event
    @registration_ids_by_event ||= EventRegistration
      .active
      .where(event_id: @events.map(&:id))
      .pluck(:event_id, :id)
      .each_with_object({}) { |(event_id, id), map| (map[event_id] ||= []) << id }
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

  # { registration_id => [ [ grant_id, amount_cents ], ... ] }.
  def scholarship_rows_by_registration
    @scholarship_rows_by_registration ||= Scholarship
      .joins(:allocation)
      .where(allocations: { allocatable_type: "EventRegistration", allocatable_id: registration_ids })
      .pluck(Arel.sql("allocations.allocatable_id"), :grant_id, :amount_cents)
      .each_with_object({}) { |(registration_id, grant_id, amount), map| (map[registration_id] ||= []) << [ grant_id, amount ] }
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
