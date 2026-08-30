module DataHealth
  # Facilitator affiliations minted by a registration to an event that is not a
  # facilitator training. Being a facilitator is conferred by a training, not by
  # attending anything org-linked (ADR-0003 D1), so these rows should not exist —
  # they inflate an organization's program status and its Facilitators-since.
  #
  # The reconcile page removes them one event at a time; this finds them across
  # every event at once.
  class FacilitatorAffiliationsFromNonTrainings < Check
    def title = "Facilitator affiliations from non-training events"

    def explanation
      "Only a facilitator training confers facilitator status. These rows were created from a " \
      "registration to some other event, so they count toward program status without anyone " \
      "having trained."
    end

    def scope
      Affiliation.facilitators
        .joins(event_registration: :event)
        .where(events: { facilitator_training: false })
        .includes(:person, :organization, event_registration: :event)
    end

    def repairable? = true

    def repair_label = "Delete them"

    def repaired_message(number)
      "Deleted #{number} facilitator #{'affiliation'.pluralize(number)}."
    end

    # destroy, not delete_all: the organization's status and affiliation dates are
    # kept in step by Affiliation's after_destroy callbacks.
    def repair!
      scope.to_a.each(&:destroy!).size
    end

    def describe(affiliation)
      "#{affiliation.person&.name} — #{affiliation.organization&.name} " \
      "(from #{affiliation.event_registration&.event&.title})"
    end
  end
end
