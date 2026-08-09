# Per-event scholarship figures for the cross-event scholarship report, loaded for
# every event at once in a handful of grouped queries instead of one EventDashboard
# (and its ~8 queries) per event.
#
# Mirrors EventDashboard's funded/unfunded split (Scholarship.externally_funded /
# .org_subsidized) and its active-registrations-only scope, so a report column and
# that event's dashboard can't disagree — a parity spec holds the two together.
#
# Pass funder: (a Person/Organization) to narrow to scholarships drawn from that
# funder's grants, matching EventDashboard.new(event, scholarship_funder:).
class EventScholarshipFigures
  Figures = Struct.new(
    :funded_cents,
    :unfunded_cents,
    :funded_count,
    :unfunded_count,
    :attended_count,
    # { Person id => cents } per split, and the matching name-sorted Person
    # records — the report row's expander. A recipient with no award in a split is
    # absent from it, so they can appear in one, both, or neither.
    :funded_cents_by_recipient,
    :unfunded_cents_by_recipient,
    :funded_recipients,
    :unfunded_recipients,
    keyword_init: true
  ) do
    def scholarship_cents = funded_cents + unfunded_cents
    def scholarship_count = funded_count + unfunded_count
  end

  EMPTY = Figures.new(
    funded_cents: 0,
    unfunded_cents: 0,
    funded_count: 0,
    unfunded_count: 0,
    attended_count: 0,
    funded_cents_by_recipient: {}.freeze,
    unfunded_cents_by_recipient: {}.freeze,
    funded_recipients: [].freeze,
    unfunded_recipients: [].freeze
  ).freeze

  def initialize(events, funder: nil)
    @events = events.to_a
    @funder = funder
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
    rows = registration_ids.flat_map { |id| scholarship_rows_by_registration.fetch(id, []) }
    funded, unfunded = rows.partition { |grant_id, _amount, _recipient_id| external_grant?(grant_id) }
    funded_by_recipient = cents_by_recipient(funded)
    unfunded_by_recipient = cents_by_recipient(unfunded)

    Figures.new(
      funded_cents: funded.sum { |_grant_id, amount, _recipient_id| amount },
      unfunded_cents: unfunded.sum { |_grant_id, amount, _recipient_id| amount },
      funded_count: funded.size,
      unfunded_count: unfunded.size,
      attended_count: attended_counts_by_event.fetch(event.id, 0),
      funded_cents_by_recipient: funded_by_recipient,
      unfunded_cents_by_recipient: unfunded_by_recipient,
      funded_recipients: recipients_for(funded_by_recipient.keys),
      unfunded_recipients: recipients_for(unfunded_by_recipient.keys)
    )
  end

  # { Person id => cents } for one split of a row's scholarship rows.
  def cents_by_recipient(rows)
    rows.each_with_object(Hash.new(0)) { |(_grant_id, amount, recipient_id), map| map[recipient_id] += amount }
  end

  # Name-sorted Person records for the given ids, from one lookup shared by every
  # event and both splits — so the expanders add a single Person query in total.
  def recipients_for(recipient_ids)
    recipient_ids.filter_map { |id| recipients_by_id[id] }.sort_by(&:name)
  end

  def recipients_by_id
    @recipients_by_id ||= Person
      .where(id: scholarship_rows_by_registration.values.flatten(1).map(&:last).uniq)
      .index_by(&:id)
  end

  # A grant counts as external funding only when it exists and the org didn't
  # fund it itself (AWBW) — the in-memory form of Scholarship.externally_funded.
  def external_grant?(grant_id)
    grant_id.present? && !self_funded_grant_ids.include?(grant_id)
  end

  def self_funded_grant_ids
    @self_funded_grant_ids ||= Grant.self_funded_ids.to_set
  end

  # { event_id => [ registration_id, ... ] } across every event, active only —
  # matching EventDashboard, which counts scholarships on active registrations.
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

  # { registration_id => [ [ grant_id, amount_cents, recipient_id ], ... ] },
  # optionally narrowed to the funder's grants.
  def scholarship_rows_by_registration
    @scholarship_rows_by_registration ||= begin
      scope = Scholarship
        .joins(:allocation)
        .where(allocations: { allocatable_type: "EventRegistration", allocatable_id: registration_ids })
      scope = scope.where(grant_id: funder_grant_ids) if @funder
      scope
        .pluck(Arel.sql("allocations.allocatable_id"), :grant_id, :amount_cents, :recipient_id)
        .each_with_object({}) { |(registration_id, grant_id, amount, recipient_id), map| (map[registration_id] ||= []) << [ grant_id, amount, recipient_id ] }
    end
  end

  # Ids of grants the funder gave — empty (so nothing matches) when they gave none.
  def funder_grant_ids
    @funder_grant_ids ||= Grant.where(funder: @funder).ids
  end

  # { event_id => attended registration count } from one grouped status query.
  def attended_counts_by_event
    @attended_counts_by_event ||= EventRegistration
      .status_counts_by_event(@events.map(&:id))
      .transform_values { |counts| counts.fetch("attended", 0) }
  end
end
