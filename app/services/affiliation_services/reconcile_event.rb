module AffiliationServices
  # Event-level orchestration for the "Reconcile affiliations" bulk action. Walks
  # the event's registrants and the organizations they linked, and classifies each
  # (person, org) so the confirm page can show exactly what will (and won't) happen
  # to their **owned** facilitator affiliation. Job affiliations are never touched.
  #
  # Actions:
  #   :create      — facilitator training, none exists yet but one should (pre-event
  #                  for anyone, post-event only for attendees).
  #   :deactivate  — facilitator training, an owned affiliation whose (ended)
  #                  training they didn't complete. The admin may delete it instead
  #                  of same-daying it (see `delete_keys`).
  #   :reactivate  — facilitator training, an owned affiliation same-dayed earlier,
  #                  now attended.
  #   :delete      — NOT a facilitator training: facilitator affiliation(s)
  #                  auto-created off this event that shouldn't exist.
  #   :noop        — nothing to do; the row carries a `reason` for the page.
  #
  # `preview` returns every pair (actionable and not) so the admin sees the full
  # picture; `apply` performs the kept actionable rows and stamps the event's
  # `affiliations_reconciled_at`.
  class ReconcileEvent
    Row = Struct.new(:person, :organization, :registration, :affiliation, :action, :reason, :key, keyword_init: true) do
      def actionable?
        action != :noop
      end
    end

    def self.key_for(person, organization)
      "#{person.id}:#{organization.id}"
    end

    def initialize(event)
      @event = event
    end

    def preview
      rows
    end

    # Apply the actionable rows whose keys are in `included_keys`. For :deactivate
    # rows whose key is also in `delete_keys`, delete the affiliation instead of
    # same-daying it. Stamps the event and returns the number of pairs changed.
    def apply(included_keys:, delete_keys: [])
      included = Array(included_keys).to_set
      delete_instead = Array(delete_keys).to_set

      changed = rows.count do |row|
        row.actionable? && included.include?(row.key) && perform(row, delete_instead: delete_instead.include?(row.key))
      end

      @event.update!(affiliations_reconciled_at: Time.current)
      changed
    end

    private

    def rows
      @rows ||= pairs.map do |person, organization, registration|
        action, reason, affiliation = classify(person, organization)
        Row.new(person:, organization:, registration:, affiliation:, action:, reason:, key: self.class.key_for(person, organization))
      end
    end

    def classify(person, organization)
      owned = owned_facilitators(person, organization)
      @event.facilitator_training? ? classify_training(person, organization, owned) : classify_non_training(person, organization, owned)
    end

    def classify_training(person, organization, owned)
      attended = completed_training?(person, organization)

      if owned.any?
        return [ :reactivate, nil, owned.find { |a| !a.active? } ] if attended && owned.any? { |a| !a.active? }
        return [ :noop, "Active — attended", owned.first ] if attended

        deactivatable = owned.select { |a| a.active? && source_ended?(a) }
        return [ :deactivate, nil, deactivatable.first ] if deactivatable.any?
        return [ :noop, "Already deactivated — didn't attend", owned.first ] if owned.none?(&:active?)

        [ :noop, "Training hasn't ended yet", owned.first ]
      elsif hand_facilitator?(person, organization)
        [ :noop, "Hand-entered affiliation — left alone", nil ]
      elsif !@event.ended? || attended
        [ :create, nil, nil ]
      else
        [ :noop, "Didn't attend — no affiliation to create", nil ]
      end
    end

    def classify_non_training(person, organization, owned)
      from_event = owned.select { |a| a.event_registration&.event_id == @event.id }
      return [ :delete, nil, from_event.first ] if from_event.any?
      return [ :noop, "Facilitator affiliation from another event — left alone", owned.first ] if owned.any?
      return [ :noop, "Hand-entered affiliation — left alone", nil ] if hand_facilitator?(person, organization)

      [ :noop, "No facilitator affiliation", nil ]
    end

    def perform(row, delete_instead:)
      case row.action
      when :create
        apply_create(row)
        true
      when :delete
        destroy_from_event(row.person, row.organization)
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

    def destroy_from_event(person, organization)
      owned_facilitators(person, organization)
        .select { |a| a.event_registration&.event_id == @event.id }
        .each(&:destroy!)
    end

    def completed_training?(person, organization)
      ReconcileFacilitatorAffiliation.new(person:, organization:).completed_training?
    end

    def source_ended?(affiliation)
      affiliation.event_registration&.event&.ended?
    end

    def hand_facilitator?(person, organization)
      person.affiliations.facilitators.where(organization:, event_registration_id: nil).active_or_pending.exists?
    end

    def owned_facilitators(person, organization)
      person.affiliations.facilitators
        .where(organization:)
        .where.not(event_registration_id: nil)
        .includes(event_registration: :event)
        .to_a
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
  end
end
