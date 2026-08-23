module AffiliationServices
  # Event-level orchestration for the "Reconcile affiliations" bulk action: asks
  # `ReconcilePerson` about each registrant's linked orgs and turns its decisions
  # into individually-selectable rows. Every rule lives there; keys, grouping and
  # the timestamp live here. Job affiliations are never touched.
  class ReconcileEvent
    Row = Struct.new(:person, :registration, :organization, :affiliation, :action, :reason, :key, keyword_init: true) do
      def actionable?
        action != :noop
      end
    end

    def initialize(event)
      @event = event
    end

    # `other_facilitators` are the person's active facilitator affiliations with orgs
    # they did NOT link on this event.
    def actionable_person_groups
      all_rows.select(&:actionable?).group_by(&:person).map do |person, rows|
        { person:, registration: rows.first.registration, rows:, other_facilitators: other_facilitators(person) }
      end
    end

    # "Active — attended" sorts second-to-last and the trivial "no affiliation" bucket
    # last; the rest alphabetical.
    def skipped_reason_sections
      grouped = all_rows.reject(&:actionable?).group_by(&:reason)
      grouped.keys.sort_by { |reason| [ reason_rank(reason), reason ] }.map { |reason| [ reason, grouped[reason] ] }
    end

    def reason_rank(reason)
      case reason
      when ReconcilePerson::ACTIVE_ATTENDED then 8
      when ReconcilePerson::NOT_ATTENDED then 9
      else 0
      end
    end

    def any_rows?
      all_rows.any?
    end

    Change = Struct.new(:person, :organization, :affiliation, :action, keyword_init: true)

    # One radio choice per row: the action itself, or "keep".
    ACTION_FOR_CHOICE = { "deactivate" => :deactivate, "delete" => :delete, "create" => :create,
                          "retarget" => :retarget }.freeze

    # What the `{ row.key => choice }` map will change, for the confirmation screen.
    def planned_changes(outcome:)
      outcome = outcome.to_h

      all_rows.select(&:actionable?).filter_map do |row|
        action = ACTION_FOR_CHOICE[outcome[row.key]]
        next unless action

        Change.new(person: row.person, organization: row.organization, affiliation: row.affiliation, action:)
      end
    end

    # Apply each row's chosen outcome, stamp the event, and return the number of
    # rows actually changed ("keep"/unknown choices are no-ops).
    def apply(outcome:)
      outcome = outcome.to_h

      changed = all_rows.count do |row|
        row.actionable? && perform_outcome(row, outcome[row.key])
      end

      @event.update!(affiliations_reconciled_at: Time.current)
      changed
    end

    private

    def all_rows
      @all_rows ||= registrations_by_person.flat_map do |person, registrations|
        registration = registrations.first
        linked_organizations(registrations).flat_map do |organization|
          reconciler(person, registration, organization).plan.map do |decision|
            row_for(person, registration, organization, decision)
          end
        end
      end
    end

    def row_for(person, registration, organization, decision)
      Row.new(person:, registration:, organization:, affiliation: decision.affiliation,
              action: decision.action, reason: decision.reason,
              key: row_key(person, organization, decision))
    end

    # Stable per-row identity for the outcome map: the affiliation itself when there
    # is one, else the (person, org) pair the row would create an affiliation for.
    def row_key(person, organization, decision)
      return "aff:#{decision.affiliation.id}" if decision.affiliation

      "#{decision.actionable? ? decision.action : 'none'}:#{person.id}:#{organization.id}"
    end

    def perform_outcome(row, choice)
      action = ACTION_FOR_CHOICE[choice]
      return false unless action

      reconciler(row.person, row.registration, row.organization).perform(action, affiliation: row.affiliation)
    end

    # One reconciler per (person, org) — reused for both planning and applying so the
    # attendance lookup behind each decision runs once.
    def reconciler(person, registration, organization)
      @reconcilers ||= {}
      @reconcilers[[ person.id, organization.id ]] ||= ReconcilePerson.new(
        person:, organization:, event: @event, registration:, include_unowned: true
      )
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
