module DataHealth
  # Registrations carrying more in payments, scholarships, and discounts than they
  # cost — on the registration itself or on one of its CE registrations. The
  # registrants list flags these one event at a time; this lists them all.
  class OverAllocatedRegistrations < Check
    def title = "Registrations paid beyond their cost"

    def explanation
      "More has been allocated than the registration or its CE costs, usually from a merge folding " \
      "two paid records together or a payment left on a now-free event. Each needs a refund or a " \
      "moved payment, decided case by case."
    end

    def scope
      EventRegistration.where(id: over_allocated_ids)
        .or(EventRegistration.where(id: over_allocated_ce_registration_ids))
        .includes(:registrant, :event, :allocations, continuing_education_registrations: :allocations)
    end

    def describe(registration)
      over = registration.over_allocation_cents + registration.ce_over_allocation_cents
      "#{registration.registrant&.name} — #{registration.event&.title} " \
      "(over by #{MoneyFormatter.dollars_from_cents(over)})"
    end

    def path_for(registration) = event_registration_path(registration)

    private

    def over_allocated_ids
      EventRegistration.joins(:event, :allocations)
        .group("event_registrations.id", "events.cost_cents")
        .having("SUM(allocations.amount) > COALESCE(events.cost_cents, 0)")
        .select("event_registrations.id")
    end

    def over_allocated_ce_registration_ids
      ContinuingEducationRegistration.joins(:allocations)
        .group("continuing_education_registrations.id", "continuing_education_registrations.event_registration_id",
               "continuing_education_registrations.cost_cents")
        .having("SUM(allocations.amount) > COALESCE(continuing_education_registrations.cost_cents, 0)")
        .select("continuing_education_registrations.event_registration_id")
    end
  end
end
