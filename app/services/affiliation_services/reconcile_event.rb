module AffiliationServices
  # Event-level orchestration for the "Reconcile affiliations" bulk action. Walks
  # the event's registrants and the organizations they linked, and for each
  # (person, org) works out what should happen to their facilitator affiliation:
  #
  #   :create      — no facilitator affiliation exists yet but one should (heal a
  #                  missing affiliation): pre-event for any registrant, post-event
  #                  only for those who attended.
  #   :deactivate  — an owned affiliation whose (ended) training they didn't complete.
  #   :reactivate  — an owned affiliation same-dayed earlier, now attended.
  #
  # `preview` returns the actionable rows without writing so the admin can see them
  # and opt individual rows out; `apply(included_keys:)` performs the kept rows and
  # stamps the event's `affiliations_reconciled_at`.
  class ReconcileEvent
    Row = Struct.new(:person, :organization, :registration, :affiliation, :action, :key, keyword_init: true)

    def self.key_for(person, organization)
      "#{person.id}:#{organization.id}"
    end

    def initialize(event)
      @event = event
    end

    def preview
      rows
    end

    # Apply the rows whose keys are in `included_keys`, stamp the event, and return
    # the number of pairs actually changed.
    def apply(included_keys:)
      keys = Array(included_keys).to_set

      changed = rows.count do |row|
        keys.include?(row.key) && apply_row(row)
      end

      @event.update!(affiliations_reconciled_at: Time.current)
      changed
    end

    private

    def rows
      @rows ||= pairs.filter_map do |person, organization, registration|
        action = action_for(person, organization)
        next if action == :noop

        Row.new(
          person:,
          organization:,
          registration:,
          affiliation: owned_facilitator(person, organization),
          action:,
          key: self.class.key_for(person, organization)
        )
      end
    end

    def action_for(person, organization)
      reconcile = ReconcileFacilitatorAffiliation.new(person:, organization:).plan
      return reconcile unless reconcile == :noop

      create_needed?(person, organization) ? :create : :noop
    end

    def apply_row(row)
      return apply_create(row) if row.action == :create

      ReconcileFacilitatorAffiliation.call(person: row.person, organization: row.organization) != :noop
    end

    def apply_create(row)
      AffiliationServices::CreateFromRegistration.call(
        person: row.person,
        organization: row.organization,
        facilitator_training: true,
        training_date: @event.start_date,
        event_registration: row.registration
      )
      true
    end

    # A facilitator affiliation should exist but doesn't. Skip when an owned one
    # already exists (reconcile handles it — including a deliberately same-dayed
    # no-show we must not resurrect) or when a hand-created active-or-pending one
    # already covers it. Otherwise create it pre-event for anyone, post-event only
    # for those who attended.
    def create_needed?(person, organization)
      facilitators = person.affiliations.facilitators.where(organization:)
      return false if facilitators.where.not(event_registration_id: nil).exists?
      return false if facilitators.active_or_pending.exists?

      !@event.ended? || ReconcileFacilitatorAffiliation.new(person:, organization:).completed_training?
    end

    # Distinct (person, organization, registration) triples from the event's
    # registrants and the organizations each linked to their registration.
    def pairs
      @pairs ||= begin
        seen = Set.new
        @event.event_registrations.includes(:registrant, :organizations).flat_map do |registration|
          registration.organizations.filter_map do |organization|
            key = [ registration.registrant_id, organization.id ]
            next if seen.include?(key)

            seen << key
            [ registration.registrant, organization, registration ]
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
