module AffiliationServices
  # Event-level orchestration for the "Reconcile affiliations" bulk action. Walks
  # the event's registrants and, for each facilitator affiliation tied to an org
  # they linked, works out what should happen to it (job affiliations are never
  # touched). Produces one row per affiliation so each is individually actionable.
  #
  # Actions:
  #   :create      — facilitator training, none exists yet but one should (pre-event
  #                  for anyone, post-event only for attendees).
  #   :deactivate  — facilitator training, owned, its (ended) training wasn't
  #                  completed. The admin may delete it instead of same-daying it.
  #   :reactivate  — facilitator training, owned, same-dayed earlier, now attended.
  #   :delete      — NOT a facilitator training: an owned affiliation auto-created
  #                  off this event that shouldn't exist.
  #   :noop        — nothing to do; the row carries a `reason`.
  #
  # `actionable_person_groups` groups the actionable rows by person (with their
  # attendance registration and other-org facilitator affiliations for context);
  # `skipped_reason_sections` groups the no-action rows by reason. `apply` performs
  # the kept actionable rows and stamps the event. Every facilitator affiliation for
  # a linked org is reconciled — hand-entered rows included, not just app-created ones.
  class ReconcileEvent
    Row = Struct.new(:person, :registration, :organization, :affiliation, :action, :reason, :key, keyword_init: true) do
      def actionable?
        action != :noop
      end
    end

    def initialize(event)
      @event = event
    end

    # Actionable rows grouped by person: [{ person:, registration:, rows:,
    # other_facilitators: }]. `other_facilitators` are the person's active
    # facilitator affiliations with orgs they did NOT link on this event.
    def actionable_person_groups
      all_rows.select(&:actionable?).group_by(&:person).map do |person, rows|
        { person:, registration: rows.first.registration, rows:, other_facilitators: other_facilitators(person) }
      end
    end

    # No-action rows grouped by reason: [[reason, [rows]]]. "Active — attended" sorts
    # second-to-last and the trivial "no affiliation" bucket last; the rest alphabetical.
    def skipped_reason_sections
      grouped = all_rows.reject(&:actionable?).group_by(&:reason)
      grouped.keys.sort_by { |reason| [ reason_rank(reason), reason ] }.map { |reason| [ reason, grouped[reason] ] }
    end

    def reason_rank(reason)
      case reason
      when "Active — attended" then 8
      when "Didn't attend — no affiliation created" then 9
      else 0
      end
    end

    def any_rows?
      all_rows.any?
    end

    # Apply the actionable rows whose keys are in `included_keys`. For :deactivate
    # rows whose key is also in `delete_keys`, delete the affiliation instead of
    # same-daying it. Stamps the event and returns the number of rows changed.
    def apply(included_keys:, delete_keys: [])
      included = Array(included_keys).to_set
      deletes = Array(delete_keys).to_set

      changed = all_rows.count do |row|
        next false unless row.actionable?

        if deletes.include?(row.key) && row.affiliation
          row.affiliation.destroy!
          true
        elsif included.include?(row.key)
          perform(row)
        else
          false
        end
      end

      @event.update!(affiliations_reconciled_at: Time.current)
      changed
    end

    private

    def all_rows
      @all_rows ||= registrations_by_person.flat_map do |person, registrations|
        registration = registrations.first
        linked_organizations(registrations).flat_map { |organization| rows_for(person, registration, organization) }
      end
    end

    def rows_for(person, registration, organization)
      facilitators = person.affiliations.facilitators
        .where(organization:)
        .includes(event_registration: :event)
        .to_a

      unless @event.facilitator_training?
        # A non-training event confers no facilitation, so it only removes
        # facilitator affiliations that were auto-created off it.
        return facilitators.filter_map do |affiliation|
          next unless affiliation.event_registration&.event_id == @event.id

          Row.new(person:, registration:, organization:, affiliation:, action: :delete, reason: nil, key: "aff:#{affiliation.id}")
        end
      end

      attended = completed_training?(person, organization)
      rows = facilitators.map { |affiliation| affiliation_row(person, registration, organization, affiliation, attended) }
      rows << create_row(person, registration, organization, attended) if facilitators.empty?
      rows.compact
    end

    def affiliation_row(person, registration, organization, affiliation, attended)
      action, reason = classify_affiliation(affiliation, attended)
      Row.new(person:, registration:, organization:, affiliation:, action:, reason:, key: "aff:#{affiliation.id}")
    end

    # Reconciles EVERY facilitator affiliation for the org — hand-entered ones
    # included, not just app-created rows. Deactivation only applies once the
    # governing training has ended (a hand-entered row has no source training, so
    # it's gated on this event ending) — so a pre-event run never deactivates.
    def classify_affiliation(affiliation, attended)
      if attended
        affiliation.active? ? [ :noop, "Active — attended" ] : [ :reactivate, nil ]
      elsif affiliation.active? && deactivation_ready?(affiliation)
        [ :deactivate, nil ]
      elsif affiliation.active?
        [ :noop, "Training hasn't ended yet" ]
      else
        [ :noop, "Already deactivated — didn't attend" ]
      end
    end

    def deactivation_ready?(affiliation)
      affiliation.event_registration_id ? source_ended?(affiliation) : @event.ended?
    end

    def create_row(person, registration, organization, attended)
      if !@event.ended? || attended
        Row.new(person:, registration:, organization:, affiliation: nil, action: :create, reason: nil,
                key: "create:#{person.id}:#{organization.id}")
      else
        Row.new(person:, registration:, organization:, affiliation: nil, action: :noop,
                reason: "Didn't attend — no affiliation created", key: "none:#{person.id}:#{organization.id}")
      end
    end

    def perform(row)
      case row.action
      when :create
        AffiliationServices::CreateFromRegistration.call(
          person: row.person, organization: row.organization, facilitator_training: true,
          training_date: @event.start_date, event_registration: row.registration
        )
      when :delete
        row.affiliation.destroy!
      when :deactivate
        # Same-day it: end_date = the affiliation's own start_date (start_date itself
        # is never changed), which the model turns into inactive.
        row.affiliation.update!(end_date: row.affiliation.start_date || Date.current)
      when :reactivate
        row.affiliation.update!(end_date: nil)
      end
      true
    end

    def completed_training?(person, organization)
      ReconcileFacilitatorAffiliation.new(person:, organization:).completed_training?
    end

    def source_ended?(affiliation)
      affiliation.event_registration&.event&.ended?
    end

    def other_facilitators(person)
      person.affiliations.active.facilitators
        .where.not(organization_id: linked_org_ids(person))
        .includes(:organization)
        .to_a
    end

    def linked_org_ids(person)
      linked_organizations(registrations_by_person[person]).map(&:id)
    end

    def linked_organizations(registrations)
      registrations.flat_map(&:organizations).uniq
    end

    def registrations_by_person
      @registrations_by_person ||= @event.event_registrations.includes(:registrant, :organizations).group_by(&:registrant)
    end
  end
end
