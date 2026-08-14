module AffiliationServices
  # Event-level orchestration for the "Reconcile affiliations" bulk action. Walks
  # the event's registrants and the organizations they linked, and reconciles each
  # (person, org)'s owned facilitator affiliation via ReconcileFacilitatorAffiliation.
  #
  # `preview` returns the actionable rows (nothing is written) so the admin can see
  # what will change and opt individual rows out. `apply` reconciles the rows the
  # admin kept (by key) and stamps the event's `affiliations_reconciled_at`.
  class ReconcileEvent
    Row = Struct.new(:person, :organization, :affiliation, :action, :key, keyword_init: true)

    def self.key_for(person, organization)
      "#{person.id}:#{organization.id}"
    end

    def initialize(event)
      @event = event
    end

    # Actionable rows (:deactivate / :reactivate) for the preview. Never writes.
    def preview
      pairs.filter_map do |person, organization|
        action = ReconcileFacilitatorAffiliation.new(person:, organization:).plan
        next if action == :noop

        Row.new(
          person:,
          organization:,
          affiliation: owned_facilitator(person, organization),
          action:,
          key: self.class.key_for(person, organization)
        )
      end
    end

    # Reconcile the (person, org) pairs whose keys are in `included_keys`, stamp the
    # event, and return the number of pairs actually changed.
    def apply(included_keys:)
      keys = Array(included_keys).to_set

      changed = pairs.count do |person, organization|
        next false unless keys.include?(self.class.key_for(person, organization))

        ReconcileFacilitatorAffiliation.call(person:, organization:) != :noop
      end

      @event.update!(affiliations_reconciled_at: Time.current)
      changed
    end

    private

    # Distinct (person, organization) pairs from the event's registrants and the
    # organizations each linked to their registration.
    def pairs
      @pairs ||= begin
        seen = Set.new
        @event.event_registrations.includes(:registrant, :organizations).flat_map do |registration|
          registration.organizations.filter_map do |organization|
            key = [ registration.registrant_id, organization.id ]
            next if seen.include?(key)

            seen << key
            [ registration.registrant, organization ]
          end
        end
      end
    end

    def owned_facilitator(person, organization)
      person.affiliations.facilitators
        .where(organization:)
        .where.not(event_registration_id: nil)
        .first
    end
  end
end
