module AffiliationServices
  # Event-level orchestration for the "Reconcile affiliations" bulk action. Walks
  # the event's registrants and the organizations they linked, and per (person,
  # org) works out what should happen to their **owned** facilitator affiliation
  # (job affiliations are never touched):
  #
  #   :create      — facilitator training, none exists yet but one should (pre-event
  #                  for anyone, post-event only for attendees).
  #   :deactivate  — facilitator training, an owned affiliation whose (ended)
  #                  training they didn't complete. The admin may choose to delete
  #                  it instead of same-daying it (see `delete_keys`).
  #   :reactivate  — facilitator training, an owned affiliation same-dayed earlier,
  #                  now attended.
  #   :delete      — NOT a facilitator training: an owned facilitator affiliation was
  #                  auto-created off this event and shouldn't exist, so remove it.
  #
  # `preview` returns the actionable rows without writing so the admin can see them
  # and opt individual rows out; `apply` performs the kept rows and stamps the
  # event's `affiliations_reconciled_at`.
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

    # Apply the rows whose keys are in `included_keys`. For :deactivate rows whose
    # key is also in `delete_keys`, delete the affiliation instead of same-daying
    # it. Stamps the event and returns the number of pairs actually changed.
    def apply(included_keys:, delete_keys: [])
      included = Array(included_keys).to_set
      delete_instead = Array(delete_keys).to_set

      changed = rows.count do |row|
        included.include?(row.key) && perform(row, delete_instead: delete_instead.include?(row.key))
      end

      @event.update!(affiliations_reconciled_at: Time.current)
      changed
    end

    private

    def rows
      @rows ||= pairs.filter_map { |person, organization, registration| build_row(person, organization, registration) }
    end

    def build_row(person, organization, registration)
      if @event.facilitator_training?
        action = training_action(person, organization)
        return if action == :noop

        affiliation = action == :create ? nil : owned_facilitator(person, organization)
      else
        affiliation = owned_facilitator_from_event(person, organization)
        return if affiliation.nil?

        action = :delete
      end

      Row.new(person:, organization:, registration:, affiliation:, action:, key: self.class.key_for(person, organization))
    end

    def training_action(person, organization)
      reconcile = ReconcileFacilitatorAffiliation.new(person:, organization:).plan
      return reconcile unless reconcile == :noop

      create_needed?(person, organization) ? :create : :noop
    end

    def perform(row, delete_instead:)
      case row.action
      when :create
        apply_create(row)
        true
      when :delete
        row.affiliation.destroy!
        true
      when :deactivate
        service = ReconcileFacilitatorAffiliation.new(person: row.person, organization: row.organization)
        targets = service.deactivatable_affiliations
        return false if targets.empty?

        delete_instead ? targets.each(&:destroy!) : service.call
        true
      else # :reactivate
        ReconcileFacilitatorAffiliation.call(person: row.person, organization: row.organization) != :noop
      end
    end

    def apply_create(row)
      AffiliationServices::CreateFromRegistration.call(
        person: row.person,
        organization: row.organization,
        facilitator_training: true,
        training_date: @event.start_date,
        event_registration: row.registration
      )
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

    # An owned facilitator affiliation that was auto-created off *this* (non-training)
    # event — the row a non-training reconcile removes. Hand-created rows (no link)
    # and affiliations from other events are left alone.
    def owned_facilitator_from_event(person, organization)
      person.affiliations.facilitators
        .where(organization:)
        .where.not(event_registration_id: nil)
        .joins(:event_registration)
        .where(event_registrations: { event_id: @event.id })
        .first
    end
  end
end
