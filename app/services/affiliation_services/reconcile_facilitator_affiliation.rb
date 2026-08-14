module AffiliationServices
  # Reconciles a person's **owned** facilitator affiliation for one organization
  # against whether they actually completed a facilitator training there.
  #
  # "Owned" means auto-minted by the registration flow (`event_registration_id`
  # present) — hand-created / historical rows have no link and are left alone.
  #
  # A person is an active facilitator of an org iff they have at least one
  # `attended` registration to that org from a facilitator-training event. Anyone
  # else (no_show, cancelled, incomplete_attendance, still-registered, …) is not,
  # so we **same-day** their owned facilitator affiliation — set `end_date` to its
  # `start_date`, which the model's `set_inactive_from_dates` turns into
  # `inactive: true`. It preserves `start_date` and is reversible: if the person is
  # later marked attended, a re-run clears `end_date` and reactivates the row.
  #
  # The decision is per (person, org) across ALL their training registrations, so
  # no-showing one training but attending another for the same org keeps them
  # active.
  class ReconcileFacilitatorAffiliation
    def self.call(person:, organization:)
      new(person:, organization:).call
    end

    def initialize(person:, organization:)
      @person = person
      @organization = organization
    end

    # Apply the reconciliation. Returns the action taken (:deactivate, :reactivate,
    # or :noop).
    def call
      rows = owned_facilitator_affiliations.to_a
      return :noop if rows.empty?

      completed_training? ? reactivate(rows) : deactivate(rows)
    end

    # What #call would do, without writing. Returns :deactivate, :reactivate, or :noop.
    def plan
      rows = owned_facilitator_affiliations.to_a
      return :noop if rows.empty?

      if completed_training?
        rows.any? { |affiliation| !affiliation.active? } ? :reactivate : :noop
      elsif rows.any? { |affiliation| affiliation.active? && source_training_ended?(affiliation) }
        :deactivate
      else
        :noop
      end
    end

    private

    def deactivate(rows)
      # Only same-day affiliations whose source training has actually ended. A row
      # tied to a still-upcoming training is a legitimate assumptive/upcoming
      # affiliation — leave it alone until that training is over.
      ended = rows.select { |affiliation| affiliation.active? && source_training_ended?(affiliation) }
      return :noop if ended.empty?

      ended.each { |affiliation| affiliation.update!(end_date: affiliation.start_date || Date.current) }
      :deactivate
    end

    def source_training_ended?(affiliation)
      affiliation.event_registration&.event&.ended?
    end

    def reactivate(rows)
      ended = rows.reject(&:active?)
      return :noop if ended.empty?

      ended.each { |affiliation| affiliation.update!(end_date: nil) }
      :reactivate
    end

    def owned_facilitator_affiliations
      @person.affiliations.facilitators
        .where(organization: @organization)
        .where.not(event_registration_id: nil)
    end

    # Any `attended` registration to this org from a facilitator-training event.
    def completed_training?
      @person.event_registrations.attended
        .joins(:event).where(events: { facilitator_training: true })
        .joins(:event_registration_organizations)
        .where(event_registration_organizations: { organization_id: @organization.id })
        .exists?
    end
  end
end
