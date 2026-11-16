# Per-event scholarship figures for the cross-event scholarship report, loaded for
# every event at once in a handful of grouped queries instead of one EventDashboard
# (and its ~8 queries) per event.
#
# Mirrors EventDashboard's funded/unfunded split (Scholarship.externally_funded /
# .org_subsidized) and its money basis, so a report column and that event's
# dashboard can't disagree — a parity spec holds the two together.
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
    # Trainees whose attendance was recorded as partial. Reported alongside
    # attended_count rather than folded into it: the money stays with them, but
    # they aren't counted among those who completed the training.
    :incomplete_count,
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
    incomplete_count: 0,
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

  # One organization's share of the scholarships across every event in scope.
  OrganizationFigures = Struct.new(:funded_cents, :unfunded_cents, :award_count, :recipient_ids, keyword_init: true) do
    def scholarship_cents = funded_cents + unfunded_cents
    def recipient_count = recipient_ids.size
  end

  # { organization id => OrganizationFigures } — each award credited to the
  # organizations linked on the registration its dollars count toward (the org
  # the trainee registered under). An award on a registration linked to several
  # organizations counts under each; one linked to none falls under the nil key,
  # so nothing drops out of the report.
  def by_organization
    @by_organization ||= begin
      totals = Hash.new { |map, id| map[id] = OrganizationFigures.new(funded_cents: 0, unfunded_cents: 0, award_count: 0, recipient_ids: Set.new) }
      scholarship_rows_by_registration.each do |registration_id, rows|
        organization_ids_by_registration.fetch(registration_id, [ nil ]).each do |organization_id|
          total = totals[organization_id]
          rows.each do |grant_id, amount, recipient_id|
            external_grant?(grant_id) ? total.funded_cents += amount : total.unfunded_cents += amount
            total.award_count += 1
            total.recipient_ids << recipient_id
          end
        end
      end
      totals.default_proc = nil
      totals
    end
  end

  private

  # { registration_id => [ organization_id, ... ] } for the registrations holding
  # scholarship dollars.
  def organization_ids_by_registration
    @organization_ids_by_registration ||= EventRegistrationOrganization
      .where(event_registration_id: scholarship_rows_by_registration.keys)
      .distinct
      .pluck(:event_registration_id, :organization_id)
      .each_with_object({}) { |(registration_id, organization_id), map| (map[registration_id] ||= []) << organization_id }
  end

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
      attended_count: status_counts_by_event.dig(event.id, "attended").to_i,
      incomplete_count: status_counts_by_event.dig(event.id, "incomplete_attendance").to_i,
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

  # { event_id => [ registration_id, ... ] } across every event — the same money
  # basis as EventDashboard, so an award stays with the event of its registration.
  def registration_ids_by_event
    @registration_ids_by_event ||= EventRegistration
      .holding_money
      .where(event_id: @events.map(&:id))
      .pluck(:event_id, :id)
      .each_with_object({}) { |(event_id, id), map| (map[event_id] ||= []) << id }
  end

  def registration_ids
    @registration_ids ||= registration_ids_by_event.values.flatten
  end

  # { registration_id => [ [ grant_id, amount_cents, recipient_id ], ... ] }, keyed
  # by the registration each award's dollars count toward and optionally narrowed
  # to the funder's grants.
  def scholarship_rows_by_registration
    @scholarship_rows_by_registration ||= begin
      dollars = ScholarshipDollarRegistrations.new(registration_ids)
      scope = Scholarship
        .not_declined
        .joins(:allocation)
        .where(allocations: { allocatable_type: "EventRegistration", allocatable_id: dollars.award_registration_ids })
      scope = scope.where(grant_id: funder_grant_ids) if @funder
      scope
        .pluck(Arel.sql("allocations.allocatable_id"), :grant_id, :amount_cents, :recipient_id)
        .each_with_object({}) do |(award_registration_id, grant_id, amount, recipient_id), map|
          (map[dollars.counting_registration_id(award_registration_id)] ||= []) << [ grant_id, amount, recipient_id ]
        end
    end
  end

  # Ids of grants the funder gave — empty (so nothing matches) when they gave none.
  def funder_grant_ids
    @funder_grant_ids ||= Grant.where(funder: @funder).ids
  end

  # { event_id => { status => count } } from one grouped query — the attended and
  # incomplete-attendance headcounts both read from it. Deliberately over every
  # registration, not just the ones the money figures use: it answers who
  # completed the training, which is a different question from who was on it.
  def status_counts_by_event
    @status_counts_by_event ||= EventRegistration.status_counts_by_event(@events.map(&:id))
  end
end
